import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/models/store.dart';
import '../providers/store_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import 'store_form_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;

  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _inventoryScrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _inventoryScrollController.addListener(_onInventoryScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStoreInventory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _inventoryScrollController.removeListener(_onInventoryScroll);
    _inventoryScrollController.dispose();
    super.dispose();
  }

  void _onInventoryScroll() {
    if (_inventoryScrollController.position.pixels >=
        _inventoryScrollController.position.maxScrollExtent * 0.8) {
      // Load more when user scrolls to 80% of the list
      final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
      inventoryProvider.loadMoreStoreInventory(widget.store.id);
    }
  }

  void _loadStoreInventory() {
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    inventoryProvider.fetchStoreInventory(widget.store.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.h),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.grey.shade700,
                size: 20.w,
              ),
            ),
          ),
          flexibleSpace: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: Row(
                children: [
                  SizedBox(width: 56.w), // Space for back button
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.store.name,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${widget.store.city}, ${widget.store.state}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: EdgeInsets.all(8.w),
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
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoreFormScreen(store: widget.store),
                            ),
                          );
                          break;
                        case 'delete':
                          _showDeleteDialog(context);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Edit Store'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 20, color: Colors.red.shade600),
                            const SizedBox(width: 12),
                            Text('Delete Store', style: TextStyle(color: Colors.red.shade600)),
                          ],
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
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStoreHeader(),
            SizedBox(height: 20.h),
            
            // Quick Info Cards
            _buildQuickInfoCards(),
            SizedBox(height: 20.h),
            
            _buildInfoSection(
              'Store Information',
              Icons.store_rounded,
              [
                _buildDetailRow('Store Name', widget.store.name),
                if (widget.store.description?.isNotEmpty == true)
                  _buildDetailRow('Description', widget.store.description!),
                if (widget.store.companyName?.isNotEmpty == true)
                  _buildDetailRow('Company', widget.store.companyName!),
                if (widget.store.managerName?.isNotEmpty == true)
                  _buildDetailRow('Store Manager', widget.store.managerName!),
              ],
            ),
            SizedBox(height: 16.h),
            
            _buildInfoSection(
              'Address & Location',
              Icons.location_on_rounded,
              [
                _buildDetailRow('Full Address', widget.store.address),
                _buildDetailRow('City', widget.store.city),
                _buildDetailRow('State', widget.store.state),
                _buildDetailRow('Pincode', widget.store.pincode),
              ],
            ),
            SizedBox(height: 16.h),
            
            _buildInfoSection(
              'Contact Details',
              Icons.contact_phone_rounded,
              [
                _buildDetailRow('Phone Number', widget.store.phone),
                if (widget.store.email?.isNotEmpty == true)
                  _buildDetailRow('Email Address', widget.store.email!),
              ],
            ),
            SizedBox(height: 16.h),
            
            _buildInfoSection(
              'System Information',
              Icons.info_outline_rounded,
              [
                _buildDetailRow(
                  'Status', 
                  widget.store.isActive ? 'Active' : 'Inactive',
                  statusColor: widget.store.isActive ? Colors.green.shade600 : Colors.red.shade600,
                ),
                _buildDetailRow('Created On', _formatDate(widget.store.createdAt)),
                _buildDetailRow('Last Modified', _formatDate(widget.store.updatedAt)),
              ],
            ),
            SizedBox(height: 16.h),
            
            _buildInventorySection(),
            
            SizedBox(height: 100.h), // Extra space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoreFormScreen(store: widget.store),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Edit Store'),
      ),
    );
  }

  Widget _buildStoreHeader() {
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
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                Icons.store_rounded,
                color: AppColors.primary,
                size: 32.w,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.store.name,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  if (widget.store.companyName?.isNotEmpty == true) ...[
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        widget.store.companyName!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: widget.store.isActive
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: widget.store.isActive 
                                  ? Colors.green.shade600 
                                  : Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              widget.store.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: widget.store.isActive 
                                  ? Colors.green.shade700 
                                  : Colors.red.shade700,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildQuickInfoCards() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            'Location',
            '${widget.store.city}',
            Icons.location_city_rounded,
            Colors.blue,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildInfoCard(
            'Pincode',
            widget.store.pincode,
            Icons.pin_drop_rounded,
            Colors.green,
          ),
        ),
        if (widget.store.managerName?.isNotEmpty == true) ...[
          SizedBox(width: 12.w),
          Expanded(
            child: _buildInfoCard(
              'Manager',
              widget.store.managerName!.split(' ').first,
              Icons.person_rounded,
              Colors.purple,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20.w,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData titleIcon, List<Widget> children) {
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
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    titleIcon,
                    color: AppColors.primary,
                    size: 18.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label, 
    String value, {
    Color? statusColor,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: isHighlighted 
                ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h)
                : EdgeInsets.zero,
              decoration: isHighlighted
                ? BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  )
                : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: statusColor ?? (isHighlighted ? AppColors.primary : Colors.grey.shade900),
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInventorySection() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        // Note: Deduplication is now done server-side in the backend
        // Search is also done server-side
        var storeInventory = inventoryProvider.getStoreInventory(widget.store.id);

        final hasMore = inventoryProvider.getStoreInventoryHasMore(widget.store.id);
        final isLoadingMore = inventoryProvider.getStoreInventoryIsLoadingMore(widget.store.id);
        final totalCount = inventoryProvider.getStoreInventoryTotalCount(widget.store.id);
        

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
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.primary,
                        size: 18.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Store Inventory',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${totalCount} items',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Search Bar
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSubmitted: (value) {
                    if (value.isEmpty) {
                      inventoryProvider.fetchStoreInventory(widget.store.id);
                    } else {
                      inventoryProvider.searchStoreInventory(widget.store.id, value);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by item name, SKU, or company...',
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
                              inventoryProvider.fetchStoreInventory(widget.store.id);
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
                SizedBox(height: 16.h),
                // Loading state
                if (inventoryProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                // Empty state - no inventory at all
                else if (storeInventory.isEmpty && _searchQuery.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 40.w,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'No inventory items found',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Items will appear here when added to this store',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                // Empty state - no search results
                else if (storeInventory.isEmpty && _searchQuery.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 40.w,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'No items found',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Try adjusting your search',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // Data state - show inventory in fixed-height scrollable area
                else
                  SizedBox(
                    height: 500.h,
                    child: ListView.builder(
                      controller: _inventoryScrollController,
                      itemCount: storeInventory.length + (isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at the bottom when loading more
                        if (index == storeInventory.length) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return _buildInventoryItem(storeInventory[index]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryItem(dynamic inventory) {
    final isLowStock = inventory.isLowStock ?? false;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isLowStock ? AppColors.error.withOpacity(0.3) : AppColors.border,
          width: isLowStock ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inventory.itemName ?? 'Unknown Item',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (inventory.itemSku != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'SKU: ${inventory.itemSku}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (inventory.companyName != null) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: 12.w,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              inventory.companyName!,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
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
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 4.h,
                ),
                decoration: BoxDecoration(
                  color: isLowStock 
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  isLowStock ? 'Low Stock' : 'In Stock',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: isLowStock ? AppColors.error : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildInventoryDetail(
                  'Quantity',
                  '${inventory.quantity?.toStringAsFixed(2) ?? '0'} ${inventory.itemUnit ?? ''}',
                  Icons.inventory,
                ),
              ),
              if (inventory.itemPrice != null) ...[
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildInventoryDetail(
                    'Price',
                    '₹${inventory.itemPrice!.toStringAsFixed(2)}',
                    Icons.currency_rupee,
                  ),
                ),
              ],
            ],
          ),
          if (inventory.minStockLevel != null && inventory.minStockLevel! > 0) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _buildInventoryDetail(
                    'Min Stock',
                    inventory.minStockLevel!.toStringAsFixed(0),
                    Icons.trending_down,
                  ),
                ),
                if (inventory.maxStockLevel != null && inventory.maxStockLevel! > 0) ...[
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildInventoryDetail(
                      'Max Stock',
                      inventory.maxStockLevel!.toStringAsFixed(0),
                      Icons.trending_up,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInventoryDetail(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16.w,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Store'),
          content: Text(
            'Are you sure you want to delete "${widget.store.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            Consumer<StoreProvider>(
              builder: (context, storeProvider, child) {
                return TextButton(
                  onPressed: storeProvider.isLoading
                      ? null
                      : () async {
                          final success = await storeProvider.deleteStore(widget.store.id);
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Store deleted successfully'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: storeProvider.isLoading
                      ? SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete'),
                );
              },
            ),
          ],
        );
      },
    );
  }
}