import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/store.dart';
import '../../stores/providers/store_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/inventory_service.dart';
import '../services/transfer_service.dart';

class InventoryTransferScreen extends StatefulWidget {
  const InventoryTransferScreen({super.key});

  @override
  State<InventoryTransferScreen> createState() => _InventoryTransferScreenState();
}

class _InventoryTransferScreenState extends State<InventoryTransferScreen>
    with SingleTickerProviderStateMixin {
  final TransferService _transferService = TransferService();
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _inventoryScrollController = ScrollController();

  Store? _fromStore;
  Store? _toStore;
  List<Map<String, dynamic>> _selectedItems = [];
  List<Map<String, dynamic>> _transfers = [];
  List<Map<String, dynamic>> _storeInventory = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchQuery = '';

  // Pagination state
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true;

  // Expandable batch state
  final Set<String> _expandedBatchIds = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _inventoryScrollController.addListener(_onInventoryScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStores();
      context.read<InventoryProvider>().fetchItems();
      _loadTransfers();
    });
  }

  void _onInventoryScroll() {
    if (_inventoryScrollController.position.pixels >=
        _inventoryScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreStoreInventory();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _inventoryScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfers() async {
    try {
      setState(() => _isLoading = true);
      final transfers = await _transferService.getTransferHistory();
      setState(() {
        _transfers = transfers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFA5252),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    }
  }

  Future<void> _loadStoreInventory() async {
    if (_fromStore == null) return;

    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _storeInventory.clear();
    });

    try {
      final inventoryService = InventoryService();
      final response = await inventoryService.getStoreInventoryRaw(
        _fromStore!.id,
        page: 1,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // Filter out items with 0 or negative quantity - only show transferable items
      final inventory = List<Map<String, dynamic>>.from(response['inventory'])
          .where((item) {
            final quantity = item['quantity'] ?? 0.0;
            return quantity > 0;  // Only show items with available stock
          })
          .toList();

      setState(() {
        _storeInventory = inventory;
        _totalCount = response['count'] ?? inventory.length;
        _hasMore = response['next'] != null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFA5252),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreStoreInventory() async {
    if (_fromStore == null || !_hasMore || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final inventoryService = InventoryService();
      final response = await inventoryService.getStoreInventoryRaw(
        _fromStore!.id,
        page: _currentPage + 1,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // Filter out items with 0 or negative quantity - only show transferable items
      final inventory = List<Map<String, dynamic>>.from(response['inventory'])
          .where((item) {
            final quantity = item['quantity'] ?? 0.0;
            return quantity > 0;  // Only show items with available stock
          })
          .toList();

      setState(() {
        _storeInventory.addAll(inventory);
        _currentPage++;
        _hasMore = response['next'] != null;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty || _fromStore == null || _toStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields'),
          backgroundColor: const Color(0xFFFA5252),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare items for batch transfer - filter out items with 0 or negative quantity
      // AND validate against available quantity
      final items = _selectedItems
          .where((selectedItem) {
            final transferQty = selectedItem['transfer_quantity'];
            final availableQty = selectedItem['quantity'] ?? 0.0;  // Available in source store

            // Validate both transfer quantity and availability
            return transferQty != null &&
                   transferQty > 0 &&
                   transferQty <= availableQty;
          })
          .map((selectedItem) {
            return {
              'item_id': selectedItem['item_id'],
              'company_id': selectedItem['company_id'],
              'quantity': selectedItem['transfer_quantity'],
            };
          })
          .toList();

      // Check if there are any valid items to transfer
      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No items with valid quantity to transfer. Please check available quantities.'),
              backgroundColor: const Color(0xFFFA5252),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Warn if some items were filtered out
      final filteredCount = _selectedItems.length - items.length;
      if (filteredCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filteredCount item(s) skipped due to insufficient quantity'),
            backgroundColor: const Color(0xFFFD7E14),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Create batch transfer
      final result = await _transferService.createBatchTransfer(
        fromStoreId: _fromStore!.id,
        toStoreId: _toStore!.id,
        items: items,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        final transferCount = result['transfer_count'] ?? _selectedItems.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$transferCount items transferred successfully'),
            backgroundColor: const Color(0xFF37B24D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
        _resetForm();
        _loadTransfers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFA5252),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _fromStore = null;
      _toStore = null;
      _selectedItems.clear();
      _storeInventory.clear();
    });
    _quantityController.clear();
    _notesController.clear();
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
          'Inventory Transfer',
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4C6EF5),
          unselectedLabelColor: const Color(0xFF868E96),
          indicatorColor: const Color(0xFF4C6EF5),
          indicatorWeight: 3,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Create Transfer'),
            Tab(text: 'Transfer History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTransferTab(),
          _buildTransferHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTransferTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildStoreSelectionSection(),
          SizedBox(height: 16.h),
          if (_fromStore != null) ...[
            _buildItemSelectionSection(),
            SizedBox(height: 16.h),
          ],
          if (_selectedItems.isNotEmpty) ...[
            _buildNotesSection(),
            SizedBox(height: 24.h),
            _buildSubmitButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreSelectionSection() {
    return Container(
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
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C6EF5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    color: const Color(0xFF4C6EF5),
                    size: 20.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Transfer Route',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Consumer<StoreProvider>(
              builder: (context, storeProvider, child) {
                if (storeProvider.isLoading) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.h),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4C6EF5)),
                      ),
                    ),
                  );
                }

                if (storeProvider.stores.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFD7E14).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFFFD7E14).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFFFD7E14),
                          size: 20.w,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'No stores available',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFFFD7E14),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // From Store
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FROM STORE',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF868E96),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: _fromStore != null
                                  ? const Color(0xFF4C6EF5)
                                  : const Color(0xFFE9ECEF),
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonFormField<Store>(
                            value: _fromStore,
                            isExpanded: true,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.store_outlined,
                                color: _fromStore != null
                                    ? const Color(0xFF4C6EF5)
                                    : const Color(0xFF868E96),
                                size: 20.w,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 14.h,
                              ),
                              hintText: 'Select source store',
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: const Color(0xFF868E96),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w500,
                            ),
                            dropdownColor: Colors.white,
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              color: const Color(0xFF868E96),
                              size: 20.w,
                            ),
                            items: storeProvider.stores.map((store) {
                              return DropdownMenuItem(
                                value: store,
                                child: Text(
                                  '${store.name} (${store.companyName})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (Store? value) {
                              setState(() {
                                _fromStore = value;
                                _selectedItems.clear();
                                _storeInventory.clear();
                              });
                              if (value != null) {
                                _loadStoreInventory();
                              }
                            },
                            validator: (value) => value == null ? 'Please select source store' : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Arrow Icon
                    Icon(
                      Icons.arrow_downward,
                      color: const Color(0xFF4C6EF5),
                      size: 24.w,
                    ),
                    SizedBox(height: 16.h),
                    // To Store
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TO STORE',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF868E96),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: _toStore != null
                                  ? const Color(0xFF37B24D)
                                  : const Color(0xFFE9ECEF),
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonFormField<Store>(
                            value: _toStore,
                            isExpanded: true,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.store,
                                color: _toStore != null
                                    ? const Color(0xFF37B24D)
                                    : const Color(0xFF868E96),
                                size: 20.w,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 14.h,
                              ),
                              hintText: 'Select destination store',
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: const Color(0xFF868E96),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w500,
                            ),
                            dropdownColor: Colors.white,
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              color: const Color(0xFF868E96),
                              size: 20.w,
                            ),
                            items: storeProvider.stores
                                .where((store) => store.id != _fromStore?.id)
                                .map((store) {
                              return DropdownMenuItem(
                                value: store,
                                child: Text(
                                  '${store.name} (${store.companyName})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (Store? value) {
                              setState(() {
                                _toStore = value;
                              });
                            },
                            validator: (value) => value == null ? 'Please select destination store' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemSelectionSection() {
    return Container(
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
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF37B24D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: const Color(0xFF37B24D),
                    size: 20.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Select Items & Quantities',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (_selectedItems.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C6EF5),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '${_selectedItems.length}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20.h),
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: const Color(0xFFE9ECEF),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  // Trigger backend search immediately as user types
                  _loadStoreInventory();
                },
                onSubmitted: (value) {
                  // Already handled by onChanged
                  _loadStoreInventory();
                },
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF1A1A1A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search items by name, SKU, or company...',
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF868E96),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFF868E96),
                    size: 20.w,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: const Color(0xFF868E96),
                            size: 20.w,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                            _loadStoreInventory();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            if (_storeInventory.isEmpty) ...[
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFD7E14).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFFFD7E14).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFD7E14).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: const Color(0xFFFD7E14),
                        size: 24.w,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        'No items available in selected store',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFFFD7E14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: ListView.builder(
                  controller: _inventoryScrollController,
                  padding: EdgeInsets.all(12.w),
                  itemCount: _storeInventory.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading indicator at bottom
                    if (index == _storeInventory.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final inventory = _storeInventory[index];
                    final selectedIndex = _selectedItems.indexWhere(
                      (item) => item['item_id'] == inventory['item_id'] && item['company_id'] == inventory['company']
                    );
                    final isSelected = selectedIndex != -1;
                    final quantity = inventory['quantity'] ?? 0.0;
                    final isLowStock = quantity <= (inventory['min_stock_level'] ?? 0.0);

                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4C6EF5)
                              : const Color(0xFFE9ECEF),
                          width: isSelected ? 2 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF4C6EF5).withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(14.w),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 1.1,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedItems.add({
                                            'item_id': inventory['item_id'],
                                            'item_name': inventory['item_name'],
                                            'item_sku': inventory['item_sku'],
                                            'item_unit': inventory['item_unit'],
                                            'company_id': inventory['company'],
                                            'company_name': inventory['company_name'],
                                            'available_quantity': inventory['quantity'],
                                            'transfer_quantity': 1.0,
                                          });
                                        } else {
                                          _selectedItems.removeWhere(
                                            (item) => item['item_id'] == inventory['item_id'] && item['company_id'] == inventory['company']
                                          );
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF4C6EF5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inventory['item_name'],
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1A1A1A),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 2.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE9ECEF),
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                            child: Text(
                                              inventory['item_sku'],
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: const Color(0xFF868E96),
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          if (inventory['company_name'] != null) ...[
                                            SizedBox(width: 6.w),
                                            Icon(
                                              Icons.business,
                                              size: 12.w,
                                              color: const Color(0xFF868E96),
                                            ),
                                            SizedBox(width: 4.w),
                                            Expanded(
                                              child: Text(
                                                inventory['company_name'],
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: const Color(0xFF868E96),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLowStock
                                            ? const Color(0xFFFD7E14).withOpacity(0.1)
                                            : const Color(0xFF37B24D).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        quantity.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          color: isLowStock
                                              ? const Color(0xFFFD7E14)
                                              : const Color(0xFF37B24D),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      inventory['item_unit'],
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: const Color(0xFF868E96),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              SizedBox(height: 16.h),
                              Container(
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4C6EF5).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFF4C6EF5).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TRANSFER QUANTITY',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4C6EF5),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                    TextFormField(
                                      initialValue: _selectedItems[selectedIndex]['transfer_quantity'].toString(),
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        suffixText: inventory['item_unit'],
                                        suffixStyle: TextStyle(
                                          fontSize: 14.sp,
                                          color: const Color(0xFF868E96),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10.r),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE9ECEF),
                                            width: 1.5,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10.r),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE9ECEF),
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10.r),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF4C6EF5),
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10.r),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFFA5252),
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 12.h,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final quantity = double.tryParse(value) ?? 0.0;
                                        if (selectedIndex != -1) {
                                          setState(() {
                                            _selectedItems[selectedIndex]['transfer_quantity'] = quantity;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Required';
                                        }
                                        final quantity = double.tryParse(value.trim());
                                        if (quantity == null || quantity <= 0) {
                                          return 'Invalid quantity';
                                        }
                                        if (quantity > inventory['quantity']) {
                                          return 'Exceeds available stock';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildNotesSection() {
    return Container(
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
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF868E96).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.note_outlined,
                    color: const Color(0xFF868E96),
                    size: 20.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Transfer Notes',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'OPTIONAL',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF868E96),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                hintText: 'Enter reason for transfer or additional notes...',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF868E96),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: Color(0xFFE9ECEF),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: Color(0xFFE9ECEF),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: Color(0xFF4C6EF5),
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.all(14.w),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitTransfer,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C6EF5),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          disabledBackgroundColor: const Color(0xFFE9ECEF),
        ),
        child: _isLoading
            ? SizedBox(
                width: 22.w,
                height: 22.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 20.w),
                  SizedBox(width: 10.w),
                  Text(
                    'Complete Transfer',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTransferHistoryTab() {
    if (_isLoading && _transfers.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4C6EF5)),
        ),
      );
    }

    if (_transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32.w),
              decoration: BoxDecoration(
                color: const Color(0xFF4C6EF5).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swap_horiz,
                size: 64.w,
                color: const Color(0xFF4C6EF5),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Transfer History',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Transfer history will appear here',
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF868E96),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransfers,
      color: const Color(0xFF4C6EF5),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _transfers.length,
        itemBuilder: (context, index) {
          final item = _transfers[index];
          final type = item['type'];

          if (type == 'batch') {
            return _buildBatchHistoryCard(item['data']);
          } else {
            return _buildTransferHistoryCard(item['data']);
          }
        },
      ),
    );
  }

  Widget _buildTransferHistoryCard(Map<String, dynamic> transfer) {
    final status = transfer['status'];
    final statusColor = status == 'completed'
        ? const Color(0xFF37B24D)
        : status == 'cancelled'
            ? const Color(0xFFFA5252)
            : const Color(0xFFFD7E14);

    return Container(
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
          color: const Color(0xFFE9ECEF),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transfer['item_name'],
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (transfer['company_name'] != null) ...[
              _buildInfoRow(
                Icons.business,
                transfer['company_name'],
                const Color(0xFF4C6EF5),
              ),
              SizedBox(height: 10.h),
            ],
            _buildInfoRow(
              Icons.swap_horiz,
              '${transfer['from_store_name']} → ${transfer['to_store_name']}',
              const Color(0xFF37B24D),
            ),
            SizedBox(height: 10.h),
            _buildInfoRow(
              Icons.inventory_2_outlined,
              'Quantity: ${transfer['quantity']} ${transfer['item_unit']}',
              const Color(0xFF868E96),
            ),
            SizedBox(height: 10.h),
            _buildInfoRow(
              Icons.person_outline,
              'By: ${transfer['initiated_by_name']}',
              const Color(0xFF868E96),
            ),
            if (transfer['notes'] != null && transfer['notes'].isNotEmpty) ...[
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFE9ECEF),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 16.w,
                      color: const Color(0xFF868E96),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        transfer['notes'],
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF868E96),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 13.w,
                  color: const Color(0xFF868E96),
                ),
                SizedBox(width: 6.w),
                Text(
                  DateTime.parse(transfer['created_at']).toLocal().toString().split('.')[0],
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF868E96),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchHistoryCard(Map<String, dynamic> batch) {
    final status = batch['status'];
    final statusColor = status == 'completed'
        ? const Color(0xFF37B24D)
        : status == 'cancelled'
            ? const Color(0xFFFA5252)
            : const Color(0xFFFD7E14);

    final transfers = List<Map<String, dynamic>>.from(batch['transfers'] ?? []);
    final transferCount = batch['transfer_count'] ?? transfers.length;
    final batchId = batch['batch_id']?.toString() ?? batch['id']?.toString() ?? '';
    final isExpanded = _expandedBatchIds.contains(batchId);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedBatchIds.remove(batchId);
          } else {
            _expandedBatchIds.add(batchId);
          }
        });
      },
      child: Container(
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
            color: const Color(0xFF4C6EF5).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C6EF5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.layers,
                      size: 24.w,
                      color: const Color(0xFF4C6EF5),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Transfer',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '$transferCount items',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF868E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF4C6EF5),
                    size: 28.w,
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Store transfer route
              _buildInfoRow(
                Icons.swap_horiz,
                '${batch['from_store_name']} → ${batch['to_store_name']}',
                const Color(0xFF37B24D),
              ),
              SizedBox(height: 10.h),

              // Initiated by
              _buildInfoRow(
                Icons.person_outline,
                'By: ${batch['initiated_by_name']}',
                const Color(0xFF868E96),
              ),
              SizedBox(height: 12.h),

              // Date
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 13.w,
                    color: const Color(0xFF868E96),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    DateTime.parse(batch['created_at']).toLocal().toString().split('.')[0],
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF868E96),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Notes section (if any)
              if (batch['notes'] != null && batch['notes'].isNotEmpty) ...[
                SizedBox(height: 14.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFFDEE2E6),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF495057),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        batch['notes'],
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF868E96),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Expanded items table
              if (isExpanded && transfers.isNotEmpty) ...[
                SizedBox(height: 16.h),
                _buildExpandedItemsTable(transfers),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedItemsTable(List<Map<String, dynamic>> transfers) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Item Details',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF495057),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Quantity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF495057),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ...transfers.asMap().entries.map((entry) {
            final index = entry.key;
            final transfer = entry.value;
            final isLast = index == transfers.length - 1;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Details Column
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['item_name'] ?? 'Unknown Item',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        if (transfer['item_sku'] != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'SKU: ${transfer['item_sku']}',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: const Color(0xFF868E96),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              size: 12.w,
                              color: const Color(0xFF868E96),
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                transfer['company_name'] ?? 'No company',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF868E96),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quantity Column
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Text(
                          '${transfer['quantity']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF37B24D),
                          ),
                        ),
                        Text(
                          transfer['item_unit'] ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFF868E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            size: 16.w,
            color: color,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
