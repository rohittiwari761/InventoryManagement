import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/models/item.dart';
import '../providers/inventory_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'item_form_screen.dart';
import 'item_detail_screen.dart';
import 'add_items_to_store_screen.dart';
import 'admin_stock_management_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh items when app comes back to foreground
      context.read<InventoryProvider>().refreshItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.user?.isAdmin == true) {
                return PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'create_item':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ItemFormScreen(),
                          ),
                        );
                        break;
                      case 'manage_stock':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminStockManagementScreen(),
                          ),
                        );
                        break;
                      case 'refresh':
                        context.read<InventoryProvider>().refreshItems();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'create_item',
                      child: Row(
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text('Create New Item'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'manage_stock',
                      child: Row(
                        children: [
                          Icon(Icons.inventory),
                          SizedBox(width: 8),
                          Text('Manage Stock'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Refresh'),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<InventoryProvider>().refreshItems();
                  },
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.onPrimary,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search items by name, SKU, or HSN...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                    ),
                  ),
                ),
                
                // Filters
                if (_showFilters) ...[
                  Container(
                    margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    child: Row(
                      children: [
                        Text(
                          'Filter:',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Row(
                            children: [
                              _buildFilterChip('All', 'all'),
                              SizedBox(width: 8.w),
                              _buildFilterChip('Active', 'active'),
                              SizedBox(width: 8.w),
                              _buildFilterChip('Inactive', 'inactive'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, inventoryProvider, child) {
                if (inventoryProvider.isLoading && inventoryProvider.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (inventoryProvider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64.w,
                          color: AppColors.error,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          inventoryProvider.errorMessage!,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: () {
                            inventoryProvider.clearError();
                            inventoryProvider.refreshItems();
                          },
                          child: const Text(AppStrings.retry),
                        ),
                      ],
                    ),
                  );
                }

                return Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final isStoreUser = authProvider.user?.isStoreUser == true;
                    final isAdmin = authProvider.user?.isAdmin == true;
                    
                    // Check if we have data based on user type
                    final hasData = isStoreUser 
                        ? inventoryProvider.storeInventory.isNotEmpty
                        : inventoryProvider.items.isNotEmpty;
                    
                    if (!hasData) {
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
                              'No items found',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              isAdmin 
                                    ? 'Add existing items to stores to get started'
                                    : 'No items have been assigned to your store yet',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (isAdmin) ...[
                              SizedBox(height: 24.h),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AddItemsToStoreScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_business),
                                label: const Text('Add Items to Store'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    
                    // Get filtered items
                    final filteredItems = _getFilteredItems(
                      isStoreUser ? inventoryProvider.storeInventory : null,
                      isStoreUser ? null : inventoryProvider.items,
                    );

                    if (filteredItems.isEmpty && (_searchQuery.isNotEmpty || _filterStatus != 'all')) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64.w,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No items match your search',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Try adjusting your search terms or filters',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // Show the filtered list
                    return RefreshIndicator(
                      onRefresh: () => inventoryProvider.refreshItems(),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          if (item is StoreInventory) {
                            return _buildEnhancedStoreInventoryCard(context, item);
                          } else if (item is Item) {
                            return _buildEnhancedItemCard(context, item);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Only show add button for admins
          if (authProvider.user?.isAdmin == true) {
            return FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddItemsToStoreScreen(),
                  ),
                );
                // Refresh items only if items were successfully added
                if (result == true && mounted) {
                  if (context.mounted) {
                    context.read<InventoryProvider>().refreshItems();
                  }
                }
              },
              icon: const Icon(Icons.add_business),
              label: const Text('Add to Store'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return InkWell(
      onTap: () {
        setState(() {
          _filterStatus = value;
        });
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 6.h,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.onPrimary
              : AppColors.onPrimary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? AppColors.onPrimary
                : AppColors.onPrimary.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.primary
                : AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
  
  List<dynamic> _getFilteredItems(List<StoreInventory>? storeInventory, List<Item>? items) {
    List<dynamic> allItems = [];
    
    if (storeInventory != null) {
      allItems = storeInventory.cast<dynamic>();
    } else if (items != null) {
      allItems = items.cast<dynamic>();
    }
    
    return allItems.where((item) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        String searchableText = '';
        
        if (item is StoreInventory) {
          searchableText = '${item.itemName?.toLowerCase() ?? ''} '
              '${item.itemSku?.toLowerCase() ?? ''} '
              '${item.storeName?.toLowerCase() ?? ''}';
        } else if (item is Item) {
          searchableText = '${item.name.toLowerCase()} '
              '${item.sku.toLowerCase()} '
              '${item.hsnCode?.toLowerCase() ?? ''} '
              '${item.description?.toLowerCase() ?? ''}';
        }
        
        if (!searchableText.contains(_searchQuery)) {
          return false;
        }
      }
      
      // Status filter
      if (_filterStatus != 'all') {
        if (item is Item) {
          if (_filterStatus == 'active' && !item.isActive) return false;
          if (_filterStatus == 'inactive' && item.isActive) return false;
        }
        // For StoreInventory, we could add low stock filtering in the future
      }
      
      return true;
    }).toList();
  }

  Widget _buildEnhancedItemCard(BuildContext context, Item item) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(item: item),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.onPrimary,
                        size: 28.w,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (item.companyNames != null && item.companyNames!.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Wrap(
                              spacing: 6.w,
                              runSpacing: 6.h,
                              children: item.companyNames!.map((companyName) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.business_rounded,
                                        size: 14.w,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        companyName,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          if (item.description?.isNotEmpty == true) ...[
                            SizedBox(height: 8.h),
                            Text(
                              item.description!,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: item.isActive
                              ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
                              : [AppColors.error, AppColors.error.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: (item.isActive ? AppColors.success : AppColors.error)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 16.w,
                            color: AppColors.onPrimary,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            item.isActive ? AppStrings.active : AppStrings.inactive,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                
                // Info Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.qr_code_2_rounded,
                        'SKU',
                        item.sku,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.straighten_rounded,
                        'Unit',
                        item.unit,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.currency_rupee_rounded,
                        'Price',
                        '₹${item.price.toStringAsFixed(2)}',
                        Colors.purple,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.percent_rounded,
                        'Tax Rate',
                        '${item.taxRate.toStringAsFixed(1)}%',
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (item.hsnCode?.isNotEmpty == true) ...[
                  SizedBox(height: 12.h),
                  _buildInfoCard(
                    Icons.receipt_long_rounded,
                    'HSN Code',
                    item.hsnCode!,
                    Colors.teal,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedStoreInventoryCard(BuildContext context, StoreInventory storeItem) {
    final stockPercentage = storeItem.minStockLevel > 0 
        ? (storeItem.quantity / storeItem.minStockLevel).clamp(0.0, 1.0)
        : 0.0;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: InkWell(
        onTap: () {
          // Create Item object from StoreInventory data
          final item = Item(
            id: storeItem.item,
            name: storeItem.itemName ?? 'Unknown Item',
            sku: storeItem.itemSku ?? '',
            unit: storeItem.itemUnit ?? 'pcs',
            price: storeItem.itemPrice ?? 0.0,
            taxRate: 0.0,
            companies: [storeItem.company],
            companyNames: storeItem.companyName != null ? [storeItem.companyName!] : null,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: storeItem.lastUpdated,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(item: item),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Item Icon with Gradient Background
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.onPrimary,
                        size: 28.w,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    
                    // Item Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeItem.itemName ?? 'Unknown Item',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          if (storeItem.storeName != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.store_rounded,
                                    size: 14.w,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    storeItem.storeName!,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Stock Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: storeItem.isLowStock
                              ? [AppColors.error, AppColors.error.withValues(alpha: 0.8)]
                              : [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: (storeItem.isLowStock ? AppColors.error : AppColors.success)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            storeItem.isLowStock 
                                ? Icons.warning_amber_rounded 
                                : Icons.check_circle_rounded,
                            size: 18.w,
                            color: AppColors.onPrimary,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '${storeItem.quantity.toStringAsFixed(1)} ${storeItem.itemUnit ?? ''}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20.h),
                
                // Stock Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stock Level',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${(stockPercentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: storeItem.isLowStock ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: stockPercentage,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: storeItem.isLowStock
                                  ? [AppColors.error, Colors.orange]
                                  : [AppColors.success, Colors.green.shade400],
                            ),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16.h),
                
                // Info Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.qr_code_2_rounded,
                        'SKU',
                        storeItem.itemSku ?? 'N/A',
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.straighten_rounded,
                        'Unit',
                        storeItem.itemUnit ?? 'N/A',
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.currency_rupee_rounded,
                        'Price',
                        storeItem.itemPrice != null 
                            ? '₹${storeItem.itemPrice!.toStringAsFixed(2)}'
                            : 'N/A',
                        Colors.purple,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.trending_down_rounded,
                        'Min Stock',
                        storeItem.minStockLevel.toStringAsFixed(1),
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                
                // Low Stock Warning
                if (storeItem.isLowStock) ...[
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.error.withValues(alpha: 0.1),
                          AppColors.error.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 20.w,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Low Stock Alert - Consider Restocking Soon',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18.w,
                color: color,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

}