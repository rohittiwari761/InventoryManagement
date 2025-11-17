import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/pincode_service.dart';
import '../../../shared/models/invoice.dart';
import '../../../shared/models/item.dart';
import '../../../shared/models/store.dart';
import '../../../shared/utils/error_handler.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../user_management/providers/user_management_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/invoice_settings_provider.dart';

class InvoiceFormScreen extends StatefulWidget {
  final Invoice? invoice;

  const InvoiceFormScreen({super.key, this.invoice});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerCityController = TextEditingController();
  final _customerStateController = TextEditingController();
  final _customerPincodeController = TextEditingController();
  final _customerGstinController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  // Transport details controllers
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _transportCompanyController = TextEditingController();
  final _lrNumberController = TextEditingController();

  final _apiClient = ApiClient();
  final _pincodeService = PincodeService();
  bool _isLoadingPincode = false;

  Store? _selectedStore;
  DateTime? _dueDate;
  DateTime? _dispatchDate;
  bool _includeLogistics = false;
  final List<InvoiceItemInput> _selectedItems = [];
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, String?> _quantityErrors = {}; // Track quantity validation errors
  String _searchQuery = '';
  bool _showSearchResults = false;
  int _currentStep = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool get isEditing => widget.invoice != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Setup pincode auto-fill listener
    _customerPincodeController.addListener(_onPincodeChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });

    if (isEditing) {
      _initializeFormWithInvoice();
    }
  }

  void _onPincodeChanged() async {
    final pincode = _customerPincodeController.text;

    // Only lookup when exactly 6 digits entered
    if (pincode.length == 6 && RegExp(r'^\d{6}$').hasMatch(pincode)) {
      setState(() {
        _isLoadingPincode = true;
      });

      try {
        final details = await _pincodeService.lookupPincode(pincode);

        if (details != null && mounted) {
          setState(() {
            _customerCityController.text = details.city;
            _customerStateController.text = details.state;
            _isLoadingPincode = false;
          });
        } else {
          setState(() {
            _isLoadingPincode = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingPincode = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerCityController.dispose();
    _customerStateController.dispose();
    _customerPincodeController.dispose();
    _customerGstinController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _vehicleNumberController.dispose();
    _transportCompanyController.dispose();
    _lrNumberController.dispose();
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    // Load invoice settings first
    await context.read<InvoiceSettingsProvider>().loadSettings();

    if (user != null && !user.isAdmin) {
      await _loadUserStore();
    } else {
      await context.read<StoreProvider>().fetchStores();
    }

    // Ensure inventory is loaded for all users
    await context.read<InventoryProvider>().fetchItems();

    final inventoryProvider = context.read<InventoryProvider>();

    // Auto-set due date for new invoices based on payment terms
    if (!isEditing && _dueDate == null && mounted) {
      final settingsProvider = context.read<InvoiceSettingsProvider>();
      setState(() {
        _dueDate = DateTime.now().add(Duration(days: settingsProvider.defaultPaymentTerms));
      });
    }
  }

  Future<void> _loadUserStore() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    
    if (user == null) return;
    
    try {
      final storeProvider = context.read<StoreProvider>();
      await storeProvider.fetchStores();
      
      if (storeProvider.stores.isNotEmpty) {
        // For non-admin users, try to find a store they might be associated with
        // or just use the first available store since we don't have direct store association
        final selectedStore = storeProvider.stores.first;
        setState(() {
          _selectedStore = selectedStore;
          _currentStep = 1; // Move to next step since store is auto-selected
        });
        
        // Store inventory will be fetched in _initializeScreen()
      }
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load store information: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeFormWithInvoice() {
    if (widget.invoice == null) return;

    final invoice = widget.invoice!;
    _customerNameController.text = invoice.customerName;
    _customerAddressController.text = invoice.customerAddress ?? '';
    _customerCityController.text = invoice.customerCity ?? '';
    _customerStateController.text = invoice.customerState ?? '';
    _customerPincodeController.text = invoice.customerPincode ?? '';
    _customerGstinController.text = invoice.customerGstin ?? '';
    _customerPhoneController.text = invoice.customerPhone ?? '';
    _customerEmailController.text = invoice.customerEmail ?? '';
    _notesController.text = invoice.notes ?? '';
    _dueDate = invoice.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer5<InvoiceProvider, StoreProvider, InventoryProvider, AuthProvider, InvoiceSettingsProvider>(
      builder: (context, invoiceProvider, storeProvider, inventoryProvider, authProvider, settingsProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        children: [
                          _buildProgressIndicator(),
                          SizedBox(height: 24.h),
                          _buildStoreSection(storeProvider),
                          SizedBox(height: 20.h),
                          _buildCustomerSection(),
                          SizedBox(height: 20.h),
                          _buildInvoiceDetailsSection(),
                          SizedBox(height: 20.h),
                          _buildTransportDetailsSection(),
                          SizedBox(height: 20.h),
                          _buildItemsSection(inventoryProvider),
                          SizedBox(height: 40.h),
                          _buildActionButtons(invoiceProvider),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      expandedHeight: 120.h,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Edit Invoice' : 'Create Invoice',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (!isEditing)
              Text(
                'Professional invoice creation',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        titlePadding: EdgeInsets.only(left: 16.w, bottom: 16.h),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: AppColors.primary, size: 24.sp),
              SizedBox(width: 12.w),
              Text(
                'Invoice Creation Progress',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _buildProgressStep(0, 'Store', Icons.store),
              _buildProgressLine(0),
              _buildProgressStep(1, 'Customer', Icons.person),
              _buildProgressLine(1),
              _buildProgressStep(2, 'Details', Icons.description),
              _buildProgressLine(2),
              _buildProgressStep(3, 'Items', Icons.inventory_2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, IconData icon) {
    final isActive = step <= _currentStep;
    final isCompleted = step < _currentStep;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: isActive ? Colors.white : Colors.grey[500],
              size: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: isActive ? AppColors.primary : Colors.grey[500],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    final isCompleted = step < _currentStep;
    
    return Expanded(
      child: Container(
        height: 2.h,
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.primary : Colors.grey[300],
          borderRadius: BorderRadius.circular(1.r),
        ),
      ),
    );
  }

  Widget _buildStoreSection(StoreProvider storeProvider) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    
    // For non-admin users, show store info but don't allow selection
    if (user != null && !user.isAdmin) {
      return _buildModernSection(
        icon: Icons.store_outlined,
        title: 'Store Information',
        subtitle: _selectedStore != null 
            ? 'Invoice will be created for ${_selectedStore!.name}'
            : 'Loading store information...',
        children: [
          if (_selectedStore != null)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                color: AppColors.primary.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  Icon(Icons.store, color: AppColors.primary, size: 24.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedStore!.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_selectedStore!.address.isNotEmpty)
                          Text(
                            _selectedStore!.address,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'Your Store',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[200]!),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20.w, 
                    height: 20.h, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Loading your store information...',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    
    // For admin users, show the dropdown as before
    return _buildModernSection(
      icon: Icons.store_outlined,
      title: 'Store Information',
      subtitle: 'Select the store for this invoice',
      children: [
        _buildStoreDropdown(storeProvider),
      ],
    );
  }

  Widget _buildCustomerSection() {
    return _buildModernSection(
      icon: Icons.person_outline,
      title: 'Customer Details',
      subtitle: 'Enter customer information',
      children: [
        _buildModernTextField(
          controller: _customerNameController,
          label: 'Customer Name',
          icon: Icons.person_outline,
          isRequired: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Customer name is required';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),
        _buildModernTextField(
          controller: _customerAddressController,
          label: 'Street Address',
          icon: Icons.location_on_outlined,
          maxLines: 1,
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _customerPincodeController,
                label: 'Pincode',
                icon: Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildModernTextField(
                controller: _customerCityController,
                label: 'City',
                icon: Icons.location_city_outlined,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _customerStateController,
                label: 'State',
                icon: Icons.map_outlined,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildModernTextField(
                controller: _customerGstinController,
                label: 'GSTIN',
                icon: Icons.badge_outlined,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _customerPhoneController,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildModernTextField(
                controller: _customerEmailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty && !EmailValidator.validate(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceDetailsSection() {
    return _buildModernSection(
      icon: Icons.description_outlined,
      title: 'Invoice Details',
      subtitle: 'Set due date and notes',
      children: [
        _buildDateSelector(),
        SizedBox(height: 16.h),
        _buildModernTextField(
          controller: _notesController,
          label: 'Notes (Optional)',
          icon: Icons.note_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildTransportDetailsSection() {
    return _buildModernSection(
      icon: Icons.local_shipping_outlined,
      title: 'Transport Details',
      subtitle: 'Optional logistics information',
      children: [
        // Toggle switch for transport details
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: _includeLogistics ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: _includeLogistics ? AppColors.primary : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping,
                color: _includeLogistics ? AppColors.primary : Colors.grey.shade600,
                size: 24.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Include Transport Details',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: _includeLogistics ? AppColors.primary : Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Add driver and vehicle information',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _includeLogistics,
                onChanged: (value) {
                  setState(() {
                    _includeLogistics = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),

        // Show transport fields only when toggle is enabled
        if (_includeLogistics) ...[
          SizedBox(height: 16.h),
          _buildModernTextField(
            controller: _driverNameController,
            label: 'Driver Name',
            icon: Icons.person_outline,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  controller: _driverPhoneController,
                  label: 'Driver Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildModernTextField(
                  controller: _vehicleNumberController,
                  label: 'Vehicle Number',
                  icon: Icons.directions_car_outlined,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildModernTextField(
            controller: _transportCompanyController,
            label: 'Transport Company',
            icon: Icons.business_outlined,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  controller: _lrNumberController,
                  label: 'LR Number',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildDispatchDateSelector(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildItemsSection(InventoryProvider inventoryProvider) {
    return _buildModernSection(
      icon: Icons.inventory_2_outlined,
      title: 'Invoice Items',
      subtitle: _selectedItems.isEmpty
          ? 'Search and add items to the invoice'
          : '${_selectedItems.length} item${_selectedItems.length != 1 ? 's' : ''} selected',
      children: [
        // Show message if no store is selected
        if (_selectedStore == null)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade700,
                  size: 24.w,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Please select a store first to view and add items',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (inventoryProvider.isLoading)
          Container(
            padding: EdgeInsets.all(24.w),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Loading inventory...',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          _buildModernSearchBar(),

          if (_showSearchResults && _searchQuery.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 12.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildSearchResults(inventoryProvider),
            ),

          SizedBox(height: 20.h),

          if (_selectedItems.isNotEmpty) ...[
            _buildSelectedItemsHeader(),
            SizedBox(height: 12.h),
            ..._selectedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildModernSelectedItemCard(item, index, inventoryProvider);
            }),
          ] else
            _buildEmptyItemsState(),
        ],
      ],
    );
  }

  Widget _buildModernSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool isRequired = false,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.grey[50],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        style: TextStyle(fontSize: 16.sp),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          labelStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
          counterText: maxLength != null ? '' : null, // Hide character counter
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[200]!),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.primary),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                _dueDate == null
                    ? 'Select Due Date (Optional)'
                    : 'Due Date: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                style: TextStyle(
                  color: _dueDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 16.sp,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchDateSelector() {
    return InkWell(
      onTap: () => _selectDispatchDate(context),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[200]!),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: AppColors.primary, size: 20.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _dispatchDate == null
                    ? 'Dispatch Date'
                    : '${_dispatchDate!.day}/${_dispatchDate!.month}/${_dispatchDate!.year}',
                style: TextStyle(
                  color: _dispatchDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 14.sp,
                ),
              ),
            ),
            if (_dispatchDate != null)
              Icon(Icons.check_circle, color: AppColors.success, size: 16.w),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _searchQuery.isNotEmpty 
              ? AppColors.primary.withOpacity(0.3)
              : Colors.grey[300]!,
          width: 1.5,
        ),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _showSearchResults = value.isNotEmpty;
          });
        },
        style: TextStyle(
          fontSize: 16.sp,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search items to add to invoice...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: EdgeInsets.only(left: 4.w, right: 8.w),
            child: Icon(
              Icons.search_rounded, 
              color: _searchQuery.isNotEmpty 
                  ? AppColors.primary 
                  : AppColors.textSecondary,
              size: 24.sp,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? Container(
                  margin: EdgeInsets.only(right: 4.w),
                  child: IconButton(
                    icon: Icon(
                      Icons.clear_rounded, 
                      color: AppColors.textSecondary,
                      size: 20.sp,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _showSearchResults = false;
                      });
                    },
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 18.h,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSelectedItemsHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.primary),
          SizedBox(width: 12.w),
          Text(
            'Selected Items (${_selectedItems.length})',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    return Container(
      padding: EdgeInsets.all(40.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.grey[200]!,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 48.sp,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'No items added yet',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Search and select items above to add them to the invoice',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(InvoiceProvider invoiceProvider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[300]!),
              padding: EdgeInsets.symmetric(vertical: 18.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: invoiceProvider.isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 18.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.3),
            ),
            child: invoiceProvider.isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEditing ? Icons.update : Icons.add,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        isEditing ? 'Update Invoice' : 'Create Invoice',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreDropdown(StoreProvider storeProvider) {
    if (storeProvider.isLoading) {
      return Container(
        height: 56.h,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12.r),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12.w),
            Text('Loading stores...'),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.grey[50],
      ),
      child: DropdownButtonFormField<Store>(
        value: _selectedStore,
        decoration: InputDecoration(
          labelText: 'Select Store *',
          prefixIcon: Icon(Icons.store, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
        items: storeProvider.stores.map((store) => DropdownMenuItem(
          value: store,
          child: Text(store.name),
        )).toList(),
        onChanged: (store) async {
          setState(() {
            _selectedStore = store;
            _currentStep = 1; // Move to next step
          });
          if (store != null && mounted) {
            await context.read<InventoryProvider>().fetchStoreInventory(store.id);
          }
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a store';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSearchResults(InventoryProvider inventoryProvider) {
    // Get store-specific inventory if a store is selected
    final storeInventory = _selectedStore != null
        ? inventoryProvider.getStoreInventory(_selectedStore!.id)
        : inventoryProvider.storeInventory;

    final filteredInventory = storeInventory.where((inventory) {
      final itemName = (inventory.itemName ?? '').toLowerCase();
      final itemSku = (inventory.itemSku ?? '').toLowerCase();
      return itemName.contains(_searchQuery.toLowerCase()) || 
             itemSku.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredInventory.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48.sp, color: AppColors.textSecondary),
            SizedBox(height: 12.h),
            Text(
              'No items found',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Try searching with a different keyword',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredInventory.take(5).map((inventory) => 
        _buildInventorySearchCard(inventory)
      ).toList(),
    );
  }

  Widget _buildInventorySearchCard(StoreInventory inventory) {
    final isSelected = _selectedItems.any((selected) => selected.itemId == inventory.item && selected.companyId == inventory.company);
    final currentStock = inventory.quantity;
    final isOutOfStock = currentStock <= 0;
    
    Color stockColor = AppColors.success;
    String stockText = 'In Stock';
    if (isOutOfStock) {
      stockColor = AppColors.error;
      stockText = 'Out of Stock';
    } else if (inventory.isLowStock) {
      stockColor = Colors.orange;
      stockText = 'Low Stock';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: isOutOfStock ? null : () => _selectItem(inventory),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : Border.all(color: Colors.grey[200]!),
            color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.grey[200]!,
                  ),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.inventory_2_outlined,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inventory.itemName ?? 'Unknown Item',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      inventory.companyName ?? 'Unknown Company',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: stockColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: stockColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory, size: 12.sp, color: stockColor),
                              SizedBox(width: 4.w),
                              Text(
                                '$currentStock ${inventory.itemUnit ?? 'units'}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: stockColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '₹${(inventory.itemPrice ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
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
      ),
    );
  }

  Widget _buildModernSelectedItemCard(InvoiceItemInput item, int index, InventoryProvider inventoryProvider) {
    // Get store-specific inventory if a store is selected
    final storeInventory = _selectedStore != null
        ? inventoryProvider.getStoreInventory(_selectedStore!.id)
        : inventoryProvider.storeInventory;

    final inventory = storeInventory.firstWhere(
      (inv) => inv.item == item.itemId && inv.company == item.companyId,
      orElse: () => StoreInventory(
        id: 0,
        store: _selectedStore?.id ?? 0,
        company: item.companyId,
        item: item.itemId,
        quantity: 0,
        minStockLevel: 0,
        maxStockLevel: 0,
        isLowStock: false,
        lastUpdated: DateTime.now(),
        itemName: 'Unknown Item',
        itemSku: '',
        itemUnit: 'units',
        itemPrice: 0.0,
      ),
    );

    // Use unique key combining itemId and companyId for controllers
    final controllerKey = '${item.itemId}_${item.companyId}';
    final quantityController = _quantityControllers[controllerKey] ??= TextEditingController(text: item.quantity.toString());
    final priceController = _priceControllers[controllerKey] ??= TextEditingController(text: (item.customPrice ?? inventory.itemPrice ?? 0.0).toString());

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                  Icons.inventory_2,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inventory.itemName ?? 'Unknown Item',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      inventory.companyName ?? 'Unknown Company',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeItem(index),
                icon: Icon(Icons.remove_circle, color: AppColors.error),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(
                            color: _quantityErrors[controllerKey] != null
                                ? AppColors.error
                                : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(
                            color: _quantityErrors[controllerKey] != null
                                ? AppColors.error
                                : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(
                            color: _quantityErrors[controllerKey] != null
                                ? AppColors.error
                                : AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.error),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.error, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        errorText: _quantityErrors[controllerKey],
                        errorStyle: TextStyle(fontSize: 11.sp),
                      ),
                      onChanged: (value) {
                        final quantity = double.tryParse(value) ?? 1.0;

                        // Real-time inventory validation
                        String? error;
                        if (quantity > inventory.quantity) {
                          error = 'Only ${inventory.quantity.toStringAsFixed(0)} ${inventory.itemUnit ?? 'units'} available';
                        }

                        setState(() {
                          _quantityErrors[controllerKey] = error;
                          _selectedItems[index] = InvoiceItemInput(
                            itemId: item.itemId,
                            companyId: item.companyId,
                            quantity: quantity,
                            customPrice: item.customPrice,
                            taxRate: item.taxRate,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit Price',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextFormField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: '₹',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      ),
                      onChanged: (value) {
                        final price = double.tryParse(value) ?? 0.0;
                        setState(() {
                          _selectedItems[index] = InvoiceItemInput(
                            itemId: item.itemId,
                            companyId: item.companyId,
                            quantity: item.quantity,
                            customPrice: price,
                            taxRate: item.taxRate,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line Total',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '₹${(item.quantity * (item.customPrice ?? inventory.itemPrice ?? 0.0)).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectItem(StoreInventory inventory) {
    if (_selectedItems.any((selected) => selected.itemId == inventory.item && selected.companyId == inventory.company)) {
      return; // Already selected
    }

    final settingsProvider = context.read<InvoiceSettingsProvider>();

    setState(() {
      _selectedItems.insert(0, InvoiceItemInput(
        itemId: inventory.item,
        companyId: inventory.company,
        quantity: 1.0,
        customPrice: inventory.itemPrice,
        taxRate: settingsProvider.defaultTaxRate, // Use default tax rate from settings
      ));
      _currentStep = 3; // Move to items step

      // Clear search
      _searchController.clear();
      _searchQuery = '';
      _showSearchResults = false;
    });
  }

  void _removeItem(int index) {
    setState(() {
      final item = _selectedItems[index];
      _selectedItems.removeAt(index);
      // Use unique key combining itemId and companyId for controllers
      final controllerKey = '${item.itemId}_${item.companyId}';
      _quantityControllers[controllerKey]?.dispose();
      _priceControllers[controllerKey]?.dispose();
      _quantityControllers.remove(controllerKey);
      _priceControllers.remove(controllerKey);
      _quantityErrors.remove(controllerKey); // Clear quantity error
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectDispatchDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dispatchDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dispatchDate) {
      setState(() {
        _dispatchDate = picked;
      });
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    // Only require store selection for admin users
    if (user != null && user.isAdmin && _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a store'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      return;
    }

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one item'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      return;
    }

    // Check for quantity validation errors
    if (_quantityErrors.values.any((error) => error != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fix quantity errors before submitting'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      return;
    }

    try {
      final invoiceProvider = context.read<InvoiceProvider>();
      final settingsProvider = context.read<InvoiceSettingsProvider>();

      Invoice? invoice;
      if (isEditing) {
        final success = await invoiceProvider.updateInvoice(
          id: widget.invoice!.id,
          customerName: _customerNameController.text,
          customerAddress: _customerAddressController.text.isEmpty ? null : _customerAddressController.text,
          customerGstin: _customerGstinController.text.isEmpty ? null : _customerGstinController.text,
          customerPhone: _customerPhoneController.text.isEmpty ? null : _customerPhoneController.text,
          customerEmail: _customerEmailController.text.isEmpty ? null : _customerEmailController.text,
          items: _selectedItems,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          dueDate: _dueDate,
          includeLogistics: _includeLogistics,
          driverName: _driverNameController.text.isEmpty ? null : _driverNameController.text,
          driverPhone: _driverPhoneController.text.isEmpty ? null : _driverPhoneController.text,
          vehicleNumber: _vehicleNumberController.text.isEmpty ? null : _vehicleNumberController.text,
          transportCompany: _transportCompanyController.text.isEmpty ? null : _transportCompanyController.text,
          lrNumber: _lrNumberController.text.isEmpty ? null : _lrNumberController.text,
          dispatchDate: _dispatchDate,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Invoice updated successfully'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // For non-admin users, don't pass store/company IDs (backend will auto-assign)
        if (user != null && !user.isAdmin) {
          invoice = await invoiceProvider.createInvoice(
            companyId: null, // Backend will auto-assign
            storeId: null,   // Backend will auto-assign
            customerName: _customerNameController.text,
            customerAddress: _customerAddressController.text.isEmpty ? null : _customerAddressController.text,
            customerCity: _customerCityController.text.isEmpty ? null : _customerCityController.text,
            customerState: _customerStateController.text.isEmpty ? null : _customerStateController.text,
            customerPincode: _customerPincodeController.text.isEmpty ? null : _customerPincodeController.text,
            customerGstin: _customerGstinController.text.isEmpty ? null : _customerGstinController.text,
            customerPhone: _customerPhoneController.text.isEmpty ? null : _customerPhoneController.text,
            customerEmail: _customerEmailController.text.isEmpty ? null : _customerEmailController.text,
            items: _selectedItems,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            termsAndConditions: settingsProvider.defaultTermsAndConditions,
            dueDate: _dueDate,
            includeLogistics: _includeLogistics,
            driverName: _driverNameController.text.isEmpty ? null : _driverNameController.text,
            driverPhone: _driverPhoneController.text.isEmpty ? null : _driverPhoneController.text,
            vehicleNumber: _vehicleNumberController.text.isEmpty ? null : _vehicleNumberController.text,
            transportCompany: _transportCompanyController.text.isEmpty ? null : _transportCompanyController.text,
            lrNumber: _lrNumberController.text.isEmpty ? null : _lrNumberController.text,
            dispatchDate: _dispatchDate,
          );
        } else {
          // For admin users, pass the selected store
          invoice = await invoiceProvider.createInvoice(
            companyId: _selectedStore!.company,
            storeId: _selectedStore!.id,
            customerName: _customerNameController.text,
            customerAddress: _customerAddressController.text.isEmpty ? null : _customerAddressController.text,
            customerCity: _customerCityController.text.isEmpty ? null : _customerCityController.text,
            customerState: _customerStateController.text.isEmpty ? null : _customerStateController.text,
            customerPincode: _customerPincodeController.text.isEmpty ? null : _customerPincodeController.text,
            customerGstin: _customerGstinController.text.isEmpty ? null : _customerGstinController.text,
            customerPhone: _customerPhoneController.text.isEmpty ? null : _customerPhoneController.text,
            customerEmail: _customerEmailController.text.isEmpty ? null : _customerEmailController.text,
            items: _selectedItems,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            termsAndConditions: settingsProvider.defaultTermsAndConditions,
            dueDate: _dueDate,
            includeLogistics: _includeLogistics,
            driverName: _driverNameController.text.isEmpty ? null : _driverNameController.text,
            driverPhone: _driverPhoneController.text.isEmpty ? null : _driverPhoneController.text,
            vehicleNumber: _vehicleNumberController.text.isEmpty ? null : _vehicleNumberController.text,
            transportCompany: _transportCompanyController.text.isEmpty ? null : _transportCompanyController.text,
            lrNumber: _lrNumberController.text.isEmpty ? null : _lrNumberController.text,
            dispatchDate: _dispatchDate,
          );
        }

        if (invoice != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Invoice created successfully'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorHandler.parseError(e);
        
        // For inventory errors, show detailed dialog; for others, show snackbar
        if (appError.type == 'insufficient_inventory') {
          ErrorHandler.showErrorDialog(context, appError);
        } else {
          ErrorHandler.showErrorSnackBar(context, appError);
        }
      }
    }
  }
}