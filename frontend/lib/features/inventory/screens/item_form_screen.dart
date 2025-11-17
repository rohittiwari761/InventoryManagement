import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/models/item.dart';
import '../../../shared/models/company.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../providers/inventory_provider.dart';
import '../../companies/providers/company_provider.dart';

class ItemFormScreen extends StatefulWidget {
  final Item? item;

  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  final _priceController = TextEditingController();

  List<Company> _selectedCompanies = [];
  String? _selectedUnit;
  double? _selectedTaxRate;

  final List<Map<String, String>> _units = [
    {'value': 'piece', 'label': 'Piece'},
    {'value': 'meter', 'label': 'Meter'},
    {'value': 'box', 'label': 'Box'},
    {'value': 'dozen', 'label': 'Dozen'},
  ];

  final List<double> _taxRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    // Fetch companies immediately
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('DEBUG ItemFormScreen: Fetching companies...');
      await context.read<CompanyProvider>().fetchCompanies();
      print('DEBUG ItemFormScreen: Companies fetched: ${context.read<CompanyProvider>().companies.length}');

      if (isEditing) {
        _populateFields();
      }
    });
  }

  void _populateFields() {
    final item = widget.item!;
    _nameController.text = item.name;
    _descriptionController.text = item.description ?? '';
    _skuController.text = item.sku;
    _hsnCodeController.text = item.hsnCode ?? '';
    _selectedUnit = _units.any((unit) => unit['value'] == item.unit)
        ? item.unit
        : _units.first['value'];
    _priceController.text = item.price.toString();
    _selectedTaxRate = _taxRates.contains(item.taxRate)
        ? item.taxRate
        : _taxRates.first;

    final companies = context.read<CompanyProvider>().companies;
    _selectedCompanies = companies
        .where((company) => item.companies.contains(company.id))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _hsnCodeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'Please enter a valid number';
    }
    if (double.parse(value.trim()) < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  String? _validateDropdown(dynamic value, String fieldName) {
    if (value == null) {
      return '$fieldName is required';
    }
    return null;
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompanies.isEmpty ||
        _selectedUnit == null ||
        _selectedTaxRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields and select at least one company'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final inventoryProvider = context.read<InventoryProvider>();

    bool success;
    final companyIds = _selectedCompanies.map((c) => c.id).toList();

    if (isEditing) {
      success = await inventoryProvider.updateItem(
        id: widget.item!.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        sku: _skuController.text.trim(),
        hsnCode: _hsnCodeController.text.trim().isEmpty
            ? null
            : _hsnCodeController.text.trim(),
        unit: _selectedUnit!,
        price: double.parse(_priceController.text.trim()),
        taxRate: _selectedTaxRate!,
        companies: companyIds,
      );
    } else {
      success = await inventoryProvider.createItem(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        sku: _skuController.text.trim(),
        hsnCode: _hsnCodeController.text.trim().isEmpty
            ? null
            : _hsnCodeController.text.trim(),
        unit: _selectedUnit!,
        price: double.parse(_priceController.text.trim()),
        taxRate: _selectedTaxRate!,
        companies: companyIds,
      );

    }

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Item updated successfully'
                : 'Item created successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add Item'),
        actions: [
          Consumer<InventoryProvider>(
            builder: (context, inventoryProvider, child) {
              return TextButton(
                onPressed: inventoryProvider.isLoading ? null : _saveItem,
                child: inventoryProvider.isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(AppStrings.save),
              );
            },
          ),
        ],
      ),
      body: Consumer2<InventoryProvider, CompanyProvider>(
        builder: (context, inventoryProvider, companyProvider, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                if (inventoryProvider.errorMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20.w,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            inventoryProvider.errorMessage!,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Text(
                  'Item Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _nameController,
                  label: 'Item Name',
                  hint: 'Enter item name',
                  prefixIcon: Icons.inventory_2,
                  validator: (value) => _validateRequired(value, 'Item name'),
                ),
                SizedBox(height: 16.h),

                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Companies (Select one or more)',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        companyProvider.isLoading
                            ? Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Text(
                                      'Loading companies...',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : companyProvider.companies.isEmpty
                                ? Container(
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withOpacity(0.1),
                                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: AppColors.warning, size: 20.w),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Text(
                                            'No companies found. Please create a company first.',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Display selected companies as chips
                                      if (_selectedCompanies.isNotEmpty) ...[
                                        Wrap(
                                          spacing: 8.w,
                                          runSpacing: 8.h,
                                          children: _selectedCompanies.map((company) {
                                            return Chip(
                                              label: Text(company.name),
                                              deleteIcon: Icon(Icons.close, size: 18.w),
                                              onDeleted: () {
                                                setState(() {
                                                  _selectedCompanies.remove(company);
                                                });
                                              },
                                              backgroundColor: AppColors.primary.withOpacity(0.1),
                                              labelStyle: TextStyle(
                                                fontSize: 13.sp,
                                                color: AppColors.primary,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        SizedBox(height: 12.h),
                                      ],
                                      // Company selection dropdown
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _selectedCompanies.isEmpty
                                                ? AppColors.error
                                                : AppColors.border,
                                          ),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Column(
                                          children: companyProvider.companies.map((company) {
                                            final isSelected = _selectedCompanies.contains(company);
                                            return CheckboxListTile(
                                              title: Text(
                                                company.name,
                                                style: TextStyle(fontSize: 14.sp),
                                              ),
                                              value: isSelected,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selectedCompanies.add(company);
                                                  } else {
                                                    _selectedCompanies.remove(company);
                                                  }
                                                });
                                              },
                                              controlAffinity: ListTileControlAffinity.leading,
                                              dense: true,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      if (_selectedCompanies.isEmpty) ...[
                                        SizedBox(height: 8.h),
                                        Text(
                                          'Please select at least one company',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),


                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Enter item description',
                  prefixIcon: Icons.description,
                  maxLines: 3,
                ),
                SizedBox(height: 24.h),

                Text(
                  'Item Details',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _skuController,
                        label: 'SKU',
                        hint: 'Enter SKU code',
                        prefixIcon: Icons.qr_code,
                        validator: (value) => _validateRequired(value, 'SKU'),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: CustomTextField(
                        controller: _hsnCodeController,
                        label: 'HSN Code (Optional)',
                        hint: 'Enter HSN code',
                        prefixIcon: Icons.receipt_long,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                _buildUnitDropdown(),
                SizedBox(height: 24.h),

                Text(
                  'Pricing Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _priceController,
                        label: 'Price (₹)',
                        hint: 'Enter price',
                        prefixIcon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                        validator: (value) => _validateNumber(value, 'Price'),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(child: _buildTaxRateDropdown()),
                  ],
                ),
                SizedBox(height: 32.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          value: _selectedUnit,
          decoration: InputDecoration(
            hintText: 'Select unit',
            prefixIcon: const Icon(Icons.straighten),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
          items: _units.map((unit) {
            return DropdownMenuItem(
              value: unit['value'],
              child: Text(unit['label']!),
            );
          }).toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedUnit = value;
            });
          },
          validator: (value) => _validateDropdown(value, 'Unit'),
        ),
      ],
    );
  }


  Widget _buildTaxRateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tax Rate (%)',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<double>(
          value: _selectedTaxRate,
          decoration: InputDecoration(
            hintText: 'Tax rate',
            prefixIcon: Icon(Icons.percent, size: 20.w),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
          ),
          items: _taxRates.map((rate) {
            return DropdownMenuItem(
              value: rate,
              child: Text(
                rate == 0.0 ? '0%' : '${rate.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13.sp),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (double? value) {
            setState(() {
              _selectedTaxRate = value;
            });
          },
          validator: (value) => _validateDropdown(value, 'Tax rate'),
        ),
      ],
    );
  }
}
