import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/store.dart';
import '../../stores/providers/store_provider.dart';
import '../services/inventory_service.dart';
import 'inventory_transfer_screen.dart';

class AdminStockManagementScreen extends StatefulWidget {
  const AdminStockManagementScreen({super.key});

  @override
  State<AdminStockManagementScreen> createState() => _AdminStockManagementScreenState();
}

class _AdminStockManagementScreenState extends State<AdminStockManagementScreen>
    with SingleTickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _stockScrollController = ScrollController();

  Store? _selectedStore;
  List<Map<String, dynamic>> _storeInventory = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterType = 'all'; // all, low, out

  // Pagination state
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true;
  String? _nextUrl;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _stockScrollController.addListener(_onStockScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStores();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _stockScrollController.removeListener(_onStockScroll);
    _stockScrollController.dispose();
    super.dispose();
  }

  void _onStockScroll() {
    if (_stockScrollController.position.pixels >=
        _stockScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreInventory();
      }
    }
  }

  void _onSearchSubmitted(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
      _storeInventory.clear();
    });
    _loadStoreInventory();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 1;
      _storeInventory.clear();
    });
    _loadStoreInventory();
  }

  // Apply stock filter client-side (low stock, out of stock)
  List<Map<String, dynamic>> _getFilteredInventory() {
    if (_filterType == 'all') return _storeInventory;

    return _storeInventory.where((item) {
      final quantity = item['quantity'] ?? 0.0;
      final minLevel = item['min_stock_level'] ?? 0.0;

      if (_filterType == 'low') {
        return quantity <= minLevel && quantity > 0;
      } else if (_filterType == 'out') {
        return quantity == 0;
      }

      return true;
    }).toList();
  }

  Future<void> _loadStoreInventory() async {
    if (_selectedStore == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _storeInventory.clear();
    });

    try {
      final response = await _inventoryService.getAdminStoreStock(
        _selectedStore!.id,
        page: 1,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final inventory = List<Map<String, dynamic>>.from(response['inventory']);

      setState(() {
        _storeInventory = inventory;
        _totalCount = response['count'] ?? inventory.length;
        _hasMore = response['next'] != null;
        _nextUrl = response['next'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreInventory() async {
    if (_selectedStore == null || !_hasMore || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _inventoryService.getAdminStoreStock(
        _selectedStore!.id,
        page: _currentPage + 1,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final inventory = List<Map<String, dynamic>>.from(response['inventory']);

      setState(() {
        _storeInventory.addAll(inventory);
        _currentPage++;
        _hasMore = response['next'] != null;
        _nextUrl = response['next'];
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _showStockDialog(Map<String, dynamic> item, {bool isUpdate = false}) async {
    final quantityController = TextEditingController(
      text: isUpdate ? item['quantity'].toString() : '0'
    );
    final notesController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 400.w),
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: (isUpdate ? const Color(0xFF4C6EF5) : const Color(0xFF37B24D)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      isUpdate ? Icons.edit_outlined : Icons.add,
                      color: isUpdate ? const Color(0xFF4C6EF5) : const Color(0xFF37B24D),
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Text(
                      isUpdate ? 'Update Stock' : 'Add Stock',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['item_name'],
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'SKU: ${item['item_sku']}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF868E96),
                      ),
                    ),
                    if (item['company_name'] != null) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.business, size: 14.w, color: const Color(0xFF868E96)),
                          SizedBox(width: 4.w),
                          Text(
                            item['company_name'],
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF868E96),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Text(
                          'Current Stock: ',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF868E96),
                          ),
                        ),
                        Text(
                          '${item['quantity']} ${item['item_unit']}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                isUpdate ? 'NEW QUANTITY' : 'QUANTITY TO ADD',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF868E96),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Enter quantity',
                  suffixText: item['item_unit'],
                  suffixStyle: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF868E96),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Color(0xFF4C6EF5), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'NOTES (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF868E96),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: notesController,
                style: TextStyle(fontSize: 15.sp),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Reason for stock change...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: Color(0xFF4C6EF5), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF868E96),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final quantityText = quantityController.text.trim();
                        if (quantityText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Please enter a quantity'),
                              backgroundColor: const Color(0xFFFA5252),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                          );
                          return;
                        }

                        final quantity = double.tryParse(quantityText);
                        if (quantity == null || quantity < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Please enter a valid positive number'),
                              backgroundColor: const Color(0xFFFA5252),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        await _performStockOperation(item, quantity, isUpdate, notesController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUpdate ? const Color(0xFF4C6EF5) : const Color(0xFF37B24D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        isUpdate ? 'Update Stock' : 'Add Stock',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performStockOperation(
    Map<String, dynamic> item,
    double quantity,
    bool isUpdate,
    String notes,
  ) async {
    try {
      setState(() => _isLoading = true);

      if (isUpdate) {
        await _inventoryService.adminUpdateStock(
          itemId: item['item_id'],
          storeId: _selectedStore!.id,
          companyId: item['company'],
          quantity: quantity,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await _inventoryService.adminAddStock(
          itemId: item['item_id'],
          storeId: _selectedStore!.id,
          companyId: item['company'],
          quantity: quantity,
          notes: notes.isEmpty ? null : notes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate ? 'Stock updated successfully' : 'Stock added successfully',
            ),
            backgroundColor: const Color(0xFF37B24D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
        await _loadStoreInventory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFFA5252),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Stock Management',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_outlined, color: Color(0xFF4C6EF5)),
            tooltip: 'Transfer Inventory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InventoryTransferScreen(),
                ),
              );
            },
          ),
          SizedBox(width: 8.w),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Container(
            height: 1.h,
            color: const Color(0xFFE9ECEF),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStoreSelector(),
          if (_selectedStore != null) _buildSearchAndFilter(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllItemsTab(),
                _buildLowStockTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Consumer<StoreProvider>(
        builder: (context, storeProvider, child) {
          if (storeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (storeProvider.stores.isEmpty) {
            return Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFFE066)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: const Color(0xFFF59F00), size: 20.w),
                  SizedBox(width: 12.w),
                  const Expanded(
                    child: Text(
                      'No stores available. Create a store first.',
                      style: TextStyle(color: Color(0xFFF59F00)),
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<Store>(
              value: _selectedStore,
              decoration: InputDecoration(
                labelText: 'Select Store Location',
                labelStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF868E96),
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4C6EF5),
                ),
                prefixIcon: Container(
                  padding: EdgeInsets.all(12.w),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: const Color(0xFF4C6EF5),
                    size: 22.w,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: Color(0xFF4C6EF5), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
              ),
              items: storeProvider.stores.map((store) {
                return DropdownMenuItem<Store>(
                  value: store,
                  child: Text(
                    store.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (store) {
                setState(() {
                  _selectedStore = store;
                  _storeInventory.clear();
                });
                if (store != null) {
                  _loadStoreInventory();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 15.sp),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                // Trigger search immediately as user types
                _onSearchSubmitted(value);
              },
              onSubmitted: (value) {
                _onSearchSubmitted(value);
              },
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, or company...',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF868E96),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF868E96)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF868E96)),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Filter Chips
          Row(
            children: [
              Text(
                'Filter:',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF868E96),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Items', 'all'),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Low Stock', 'low'),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Out of Stock', 'out'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF868E96),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      selectedColor: const Color(0xFF4C6EF5),
      backgroundColor: const Color(0xFFF8F9FA),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: BorderSide(
          color: isSelected ? const Color(0xFF4C6EF5) : const Color(0xFFE9ECEF),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
    );
  }

  Widget _buildAllItemsTab() {
    if (_selectedStore == null) {
      return _buildEmptyState('Select a store to view inventory', icon: Icons.location_on_outlined);
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    final filteredInventory = _getFilteredInventory();

    if (filteredInventory.isEmpty) {
      if (_searchQuery.isNotEmpty || _filterType != 'all') {
        return _buildEmptyState('No items match your search or filter', icon: Icons.search_off);
      }
      return _buildEmptyState('No items found for this store', icon: Icons.inventory_2_outlined);
    }

    return RefreshIndicator(
      onRefresh: _loadStoreInventory,
      color: const Color(0xFF4C6EF5),
      child: ListView.builder(
        controller: _stockScrollController,
        padding: EdgeInsets.all(20.w),
        itemCount: filteredInventory.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom
          if (index == filteredInventory.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final item = filteredInventory[index];
          final quantity = item['quantity'] ?? 0.0;
          final minLevel = item['min_stock_level'] ?? 0.0;
          final isLowStock = quantity <= minLevel && quantity > 0;
          final isOutOfStock = quantity == 0;
          final uniqueKey = '${item['item_id']}_${item['company']}';
          return _buildStockItemCard(
            item,
            key: ValueKey(uniqueKey),
            isLowStock: isLowStock,
            isOutOfStock: isOutOfStock
          );
        },
      ),
    );
  }

  Widget _buildLowStockTab() {
    if (_selectedStore == null) {
      return _buildEmptyState('Select a store to view low stock items', icon: Icons.location_on_outlined);
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    final lowStockItems = _storeInventory.where((item) {
      final quantity = item['quantity'] ?? 0.0;
      final minLevel = item['min_stock_level'] ?? 0.0;
      return quantity <= minLevel;
    }).toList();

    if (lowStockItems.isEmpty) {
      return _buildEmptyState('All items are well stocked', icon: Icons.check_circle_outline, isSuccess: true);
    }

    return RefreshIndicator(
      onRefresh: _loadStoreInventory,
      color: const Color(0xFF4C6EF5),
      child: ListView.builder(
        padding: EdgeInsets.all(20.w),
        itemCount: lowStockItems.length,
        itemBuilder: (context, index) {
          final item = lowStockItems[index];
          final isOutOfStock = (item['quantity'] ?? 0.0) == 0;
          return _buildStockItemCard(item, isLowStock: true, isOutOfStock: isOutOfStock);
        },
      ),
    );
  }

  Widget _buildStockItemCard(Map<String, dynamic> item, {Key? key, bool isLowStock = false, bool isOutOfStock = false}) {
    final quantity = item['quantity'] ?? 0.0;
    final hasInventory = item['has_inventory'] ?? false;

    return Container(
      key: key,
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFFA5252).withOpacity(0.3)
              : isLowStock
                  ? const Color(0xFFFD7E14).withOpacity(0.3)
                  : const Color(0xFFE9ECEF),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C6EF5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: const Color(0xFF4C6EF5),
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 16.w),
                // Item Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['item_name'] ?? 'Unknown Item',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'SKU: ${item['item_sku'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF868E96),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item['company_name'] != null) ...[
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 14.w,
                              color: const Color(0xFF4C6EF5),
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                item['company_name'],
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4C6EF5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Status Badge
                if (isOutOfStock || isLowStock)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? const Color(0xFFFA5252).withOpacity(0.1)
                          : const Color(0xFFFD7E14).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOutOfStock ? Icons.error_outline : Icons.warning_amber_rounded,
                          size: 14.w,
                          color: isOutOfStock ? const Color(0xFFFA5252) : const Color(0xFFFD7E14),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          isOutOfStock ? 'OUT' : 'LOW',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: isOutOfStock ? const Color(0xFFFA5252) : const Color(0xFFFD7E14),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20.h),
            // Stock Info Section
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT STOCK',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF868E96),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              quantity.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: isOutOfStock
                                    ? const Color(0xFFFA5252)
                                    : isLowStock
                                        ? const Color(0xFFFD7E14)
                                        : const Color(0xFF1A1A1A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              item['item_unit'] ?? 'units',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF868E96),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasInventory && item['min_stock_level'] != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Min: ',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF868E96),
                                ),
                              ),
                              Text(
                                '${item['min_stock_level']}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Text(
                                'Max: ',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF868E96),
                                ),
                              ),
                              Text(
                                '${item['max_stock_level']}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4C6EF5), Color(0xFF4263D6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showStockDialog(item, isUpdate: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined, size: 18.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Update',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF37B24D), Color(0xFF2B9A3F)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showStockDialog(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 18.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Add Stock',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {IconData? icon, bool isSuccess = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: isSuccess
                  ? const Color(0xFF37B24D).withOpacity(0.1)
                  : const Color(0xFFF8F9FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.inventory_2_outlined,
              size: 56.w,
              color: isSuccess ? const Color(0xFF37B24D) : const Color(0xFF868E96),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF868E96),
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFA5252).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 56.w,
              color: const Color(0xFFFA5252),
            ),
          ),
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              error,
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF868E96),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _loadStoreInventory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C6EF5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 18.w),
                SizedBox(width: 8.w),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
