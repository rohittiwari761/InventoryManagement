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
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      // Load more when user scrolls to 90% of the list
      context.read<InventoryProvider>().loadMoreItems();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<InventoryProvider>().refreshItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(140.h),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Inventory',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Consumer<InventoryProvider>(
                              builder: (context, provider, child) {
                                final totalItems = provider.totalCount > 0
                                    ? provider.totalCount
                                    : provider.items.length + provider.storeInventory.length;
                                final loadedItems = provider.items.length + provider.storeInventory.length;
                                return Text(
                                  provider.totalCount > loadedItems
                                    ? 'Showing $loadedItems of $totalItems items'
                                    : '$totalItems items available',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // View Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildViewToggleButton(Icons.view_list_rounded, !_isGridView),
                            _buildViewToggleButton(Icons.grid_view_rounded, _isGridView),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Menu Button
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          if (authProvider.user?.isAdmin == true) {
                            return PopupMenuButton<String>(
                              icon: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.grey.shade700,
                                  size: 20.w,
                                ),
                              ),
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
                                      Icon(Icons.add_rounded, size: 20),
                                      SizedBox(width: 12),
                                      Text('Create Item'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'manage_stock',
                                  child: Row(
                                    children: [
                                      Icon(Icons.inventory_rounded, size: 20),
                                      SizedBox(width: 12),
                                      Text('Manage Stock'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'refresh',
                                  child: Row(
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 20),
                                      SizedBox(width: 12),
                                      Text('Refresh'),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                          return IconButton(
                            onPressed: () {
                              context.read<InventoryProvider>().refreshItems();
                            },
                            icon: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.refresh_rounded,
                                color: Colors.grey.shade700,
                                size: 20.w,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12.h),
                  
                  // Search and Filter Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                              if (value.isEmpty) {
                                context.read<InventoryProvider>().fetchItems();
                              } else {
                                context.read<InventoryProvider>().searchItems(value);
                              }
                            },
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search items...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Colors.grey.shade500,
                                size: 20.w,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                        context.read<InventoryProvider>().fetchItems();
                                      },
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: Colors.grey.shade500,
                                        size: 20.w,
                                      ),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 10.h,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Filter Dropdown
                      Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            onChanged: (value) {
                              setState(() {
                                _selectedFilter = value ?? 'all';
                              });
                            },
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade600,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  child: Text(
                                    'All',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'active',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  child: Text(
                                    'Inactive',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Consumer<InventoryProvider>(
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
                    Icons.error_outline_rounded,
                    size: 64.w,
                    color: Colors.red.shade400,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    inventoryProvider.errorMessage!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  TextButton(
                    onPressed: () {
                      inventoryProvider.clearError();
                      inventoryProvider.refreshItems();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          return Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final isStoreUser = authProvider.user?.isStoreUser == true;
              final isAdmin = authProvider.user?.isAdmin == true;
              
              // Get filtered items
              final filteredItems = _getFilteredItems(
                isStoreUser ? inventoryProvider.storeInventory : null,
                isStoreUser ? null : inventoryProvider.items,
              );

              if (filteredItems.isEmpty && (_searchQuery.isNotEmpty || _selectedFilter != 'all')) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64.w,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'No items found',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Try adjusting your search or filters',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64.w,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'No items available',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        isAdmin 
                          ? 'Start by adding items to your stores'
                          : 'No items assigned to your store yet',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade500,
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
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Items to Store'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 12.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              
              return RefreshIndicator(
                onRefresh: () => inventoryProvider.refreshItems(),
                child: _isGridView
                  ? _buildGridView(filteredItems)
                  : _buildListView(filteredItems),
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.user?.isAdmin == true) {
            return FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddItemsToStoreScreen(),
                  ),
                );
                if (result == true && mounted) {
                  if (context.mounted) {
                    context.read<InventoryProvider>().refreshItems();
                  }
                }
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGridView = icon == Icons.grid_view_rounded;
        });
      },
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18.w,
          color: isSelected ? AppColors.primary : Colors.grey.shade600,
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

    // Note: Search filtering is now done server-side, so we only apply local filters here
    return allItems.where((item) {
      // Status filter (only for Items, not StoreInventory)
      if (_selectedFilter != 'all') {
        if (item is Item) {
          if (_selectedFilter == 'active' && !item.isActive) return false;
          if (_selectedFilter == 'inactive' && item.isActive) return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildListView(List<dynamic> items) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final itemCount = provider.hasMore ? items.length + 1 : items.length;
        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(16.w),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= items.length) {
              // Show loading indicator at the bottom
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final item = items[index];
            if (item is StoreInventory) {
              return _buildStoreInventoryListCard(item);
            } else if (item is Item) {
              return _buildItemListCard(item);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildGridView(List<dynamic> items) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final itemCount = provider.hasMore ? items.length + 1 : items.length;
        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(16.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16.h,
            crossAxisSpacing: 16.w,
            childAspectRatio: 0.8,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= items.length) {
              // Show loading indicator at the bottom (spans both columns)
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: const CircularProgressIndicator(),
                ),
              );
            }
            final item = items[index];
            if (item is StoreInventory) {
              return _buildStoreInventoryGridCard(item);
            } else if (item is Item) {
              return _buildItemGridCard(item);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildItemListCard(Item item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.primary,
                  size: 24.w,
                ),
              ),
              
              SizedBox(width: 16.w),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: item.isActive 
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            item.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: item.isActive 
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 4.h),
                    
                    Text(
                      'SKU: ${item.sku} • ₹${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    if (item.companyNames != null && item.companyNames!.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        item.companyNames!.join(', '),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16.w,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInventoryListCard(StoreInventory storeItem) {
    final isLowStock = storeItem.isLowStock;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isLowStock ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Icon with stock indicator
              Stack(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.store_rounded,
                      color: AppColors.primary,
                      size: 24.w,
                    ),
                  ),
                  if (isLowStock)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 16.w,
                        height: 16.h,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          size: 10.w,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              
              SizedBox(width: 16.w),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            storeItem.itemName ?? 'Unknown Item',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: isLowStock 
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '${storeItem.quantity.toStringAsFixed(1)} ${storeItem.itemUnit ?? ''}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: isLowStock 
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 4.h),
                    
                    Text(
                      'SKU: ${storeItem.itemSku ?? 'N/A'} • Min: ${storeItem.minStockLevel.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    if (storeItem.storeName != null || storeItem.companyName != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        [
                          if (storeItem.storeName != null) storeItem.storeName!,
                          if (storeItem.companyName != null) '(${storeItem.companyName!})',
                        ].join(' '),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              if (isLowStock)
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16.w,
                  color: Colors.orange.shade600,
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.w,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemGridCard(Item item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                      size: 20.w,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: item.isActive 
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      item.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: item.isActive 
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12.h),
              
              // Title
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 4.h),
              
              // SKU
              Text(
                'SKU: ${item.sku}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Price
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInventoryGridCard(StoreInventory storeItem) {
    final isLowStock = storeItem.isLowStock;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isLowStock ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with stock indicator
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.store_rounded,
                          color: AppColors.primary,
                          size: 20.w,
                        ),
                      ),
                      if (isLowStock)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: isLowStock 
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      isLowStock ? 'Low' : 'Good',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: isLowStock 
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12.h),
              
              // Title
              Text(
                storeItem.itemName ?? 'Unknown Item',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 4.h),
              
              // Store and Company name
              if (storeItem.storeName != null || storeItem.companyName != null)
                Text(
                  [
                    if (storeItem.storeName != null) storeItem.storeName!,
                    if (storeItem.companyName != null) '(${storeItem.companyName!})',
                  ].join(' '),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              
              const Spacer(),
              
              // Quantity
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: isLowStock 
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  children: [
                    Text(
                      '${storeItem.quantity.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: isLowStock 
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      ),
                    ),
                    Text(
                      storeItem.itemUnit ?? '',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}