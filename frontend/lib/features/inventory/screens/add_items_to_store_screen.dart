import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/store.dart';
import '../../../shared/models/item.dart';
import '../providers/inventory_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddItemsToStoreScreen extends StatefulWidget {
  const AddItemsToStoreScreen({super.key});

  @override
  State<AddItemsToStoreScreen> createState() => _AddItemsToStoreScreenState();
}

class _AddItemsToStoreScreenState extends State<AddItemsToStoreScreen> {
  Store? _selectedStore;
  List<ItemCompanyWithQuantity> _selectedItems = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _itemScrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _itemScrollController.addListener(_onItemScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStores();
      context.read<InventoryProvider>().fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _itemScrollController.removeListener(_onItemScroll);
    _itemScrollController.dispose();
    super.dispose();
  }

  void _onItemScroll() {
    if (_itemScrollController.position.pixels >=
        _itemScrollController.position.maxScrollExtent * 0.8) {
      final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
      inventoryProvider.loadMoreItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Items to Store'),
        actions: [
          if (_selectedStore != null && _selectedItems.isNotEmpty)
            TextButton(
              onPressed: _isLoading ? null : _submitItems,
              child: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit'),
            ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.user?.isAdmin != true) {
            return const Center(
              child: Text('Access denied. Admin privileges required.'),
            );
          }

          return Column(
            children: [
              // Step 1: Store Selection
              _buildStoreSelectionSection(),
              
              // Step 2: Item Selection (only show if store is selected)
              if (_selectedStore != null) ...[
                const Divider(),
                Expanded(child: _buildItemSelectionSection()),
              ] else
                const Expanded(child: SizedBox()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreSelectionSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '1',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Select Store',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Consumer<StoreProvider>(
            builder: (context, storeProvider, child) {
              if (storeProvider.isLoading) {
                return Container(
                  height: 56.h,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12.w),
                      const Text('Loading stores...'),
                    ],
                  ),
                );
              }

              if (storeProvider.stores.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: AppColors.error, size: 20.w),
                      SizedBox(width: 12.w),
                      const Expanded(
                        child: Text('No stores available. Create a store first.'),
                      ),
                    ],
                  ),
                );
              }

              return DropdownButtonFormField<Store>(
                value: _selectedStore,
                decoration: InputDecoration(
                  labelText: 'Select Store',
                  prefixIcon: const Icon(Icons.store),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                items: storeProvider.stores.map((store) {
                  return DropdownMenuItem(
                    value: store,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        '${store.name} (${store.companyName})',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (Store? value) {
                  setState(() {
                    _selectedStore = value;
                    _selectedItems.clear(); // Clear selected items when store changes
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '2',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Select Items & Quantities',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              
              // Selected items summary
              if (_selectedItems.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 20.w),
                      SizedBox(width: 8.w),
                      Text(
                        '${_selectedItems.length} item(s) selected',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ],
          ),
        ),
        
        // Search Bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onSubmitted: (value) {
              final inventoryProvider = context.read<InventoryProvider>();
              if (value.isEmpty) {
                inventoryProvider.fetchItems();
              } else {
                inventoryProvider.searchItems(value);
              }
            },
            decoration: InputDecoration(
              hintText: 'Search items by name or SKU...',
              hintStyle: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade500,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey.shade600,
                size: 20.w,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey.shade600,
                        size: 20.w,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        context.read<InventoryProvider>().fetchItems();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
            ),
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey.shade900,
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Items List with Fixed Height
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Consumer<InventoryProvider>(
              builder: (context, inventoryProvider, child) {
                if (inventoryProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (inventoryProvider.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64.w,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          _searchQuery.isEmpty
                            ? 'No items available to add'
                            : 'No items found',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Build list of item-company combinations
                final itemCompanyCombinations = <ItemCompanyCombination>[];
                for (final item in inventoryProvider.items) {
                  for (int i = 0; i < item.companies.length; i++) {
                    final companyId = item.companies[i];
                    final companyName = item.companyNames != null && i < item.companyNames!.length
                        ? item.companyNames![i]
                        : 'Company $companyId';
                    itemCompanyCombinations.add(
                      ItemCompanyCombination(
                        item: item,
                        companyId: companyId,
                        companyName: companyName,
                      ),
                    );
                  }
                }

                final hasMore = inventoryProvider.hasMore;
                final isLoadingMore = inventoryProvider.isLoadingMore;

                return ListView.builder(
                  controller: _itemScrollController,
                  itemCount: itemCompanyCombinations.length + (isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading indicator at bottom
                    if (index == itemCompanyCombinations.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final combination = itemCompanyCombinations[index];
                    final selectedItem = _selectedItems
                        .where((si) => si.item.id == combination.item.id && si.companyId == combination.companyId)
                        .firstOrNull;

                    return _buildItemCompanySelectionCard(combination, selectedItem);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCompanySelectionCard(
    ItemCompanyCombination combination,
    ItemCompanyWithQuantity? selectedItem,
  ) {
    final isSelected = selectedItem != null;
    final item = combination.item;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedItems.add(ItemCompanyWithQuantity(
                          item: item,
                          companyId: combination.companyId,
                          companyName: combination.companyName,
                          quantity: 1.0,
                        ));
                      } else {
                        _selectedItems.removeWhere(
                          (si) => si.item.id == item.id && si.companyId == combination.companyId,
                        );
                      }
                    });
                  },
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // Show company badge
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business, size: 12.w, color: AppColors.primary),
                            SizedBox(width: 4.w),
                            Text(
                              combination.companyName,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.description?.isNotEmpty == true) ...[
                        SizedBox(height: 4.h),
                        Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Text(
                            'SKU: ${item.sku}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Text(
                            '₹${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Quantity input (only show when selected)
            if (isSelected) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  SizedBox(width: 48.w), // Space for checkbox alignment
                  Expanded(
                    child: TextFormField(
                      initialValue: selectedItem.quantity.toString(),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final quantity = double.tryParse(value) ?? 0.0;
                        final index = _selectedItems.indexWhere(
                          (si) => si.item.id == item.id && si.companyId == combination.companyId,
                        );
                        if (index != -1) {
                          setState(() {
                            _selectedItems[index] = ItemCompanyWithQuantity(
                              item: item,
                              companyId: combination.companyId,
                              companyName: combination.companyName,
                              quantity: quantity,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    item.unit,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitItems() async {
    if (_selectedStore == null || _selectedItems.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final inventoryProvider = context.read<InventoryProvider>();
      bool allSuccessful = true;
      
      for (final itemCompanyQuantity in _selectedItems) {
        final success = await inventoryProvider.createStoreInventory(
          itemId: itemCompanyQuantity.item.id,
          storeId: _selectedStore!.id,
          companyId: itemCompanyQuantity.companyId,
          quantity: itemCompanyQuantity.quantity,
          minStockLevel: 0.0,
          maxStockLevel: 0.0,
        );
        
        if (!success) {
          allSuccessful = false;
        }
      }

      if (mounted) {
        if (allSuccessful) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedItems.length} item(s) added to ${_selectedStore!.name} successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Some items failed to add. Please try again.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class ItemCompanyWithQuantity {
  final Item item;
  final int companyId;
  final String companyName;
  final double quantity;

  ItemCompanyWithQuantity({
    required this.item,
    required this.companyId,
    required this.companyName,
    required this.quantity,
  });
}

class ItemCompanyCombination {
  final Item item;
  final int companyId;
  final String companyName;

  ItemCompanyCombination({
    required this.item,
    required this.companyId,
    required this.companyName,
  });
}