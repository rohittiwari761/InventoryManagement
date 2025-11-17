import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/models/store.dart';
import '../../../shared/models/company.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../pincodes/widgets/pincode_input_field.dart';
import '../providers/store_provider.dart';
import '../../companies/providers/company_provider.dart';

class StoreFormScreen extends StatefulWidget {
  final Store? store;

  const StoreFormScreen({super.key, this.store});

  @override
  State<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends State<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  Company? _selectedCompany;
  bool _isActive = true;

  bool get isEditing => widget.store != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
      if (isEditing) {
        _populateFields();
      }
    });
  }

  void _populateFields() {
    final store = widget.store!;
    _nameController.text = store.name;
    _descriptionController.text = store.description ?? '';
    _addressController.text = store.address;
    _cityController.text = store.city;
    _stateController.text = store.state;
    _pincodeController.text = store.pincode;
    _phoneController.text = store.phone;
    _emailController.text = store.email ?? '';
    _isActive = store.isActive;
    
    final companies = context.read<CompanyProvider>().companies;
    _selectedCompany = companies.where((company) => company.id == store.company).firstOrNull;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value.trim())) {
        return 'Please enter a valid email';
      }
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone is required';
    }
    if (value.trim().length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pincode is required';
    }
    if (value.trim().length != 6) {
      return 'Pincode must be 6 digits';
    }
    return null;
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a company'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final storeProvider = context.read<StoreProvider>();
    
    bool success;
    if (isEditing) {
      success = await storeProvider.updateStore(
        id: widget.store!.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        company: _selectedCompany!.id,
        isActive: _isActive,
      );
    } else {
      success = await storeProvider.createStore(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        company: _selectedCompany!.id,
        isActive: _isActive,
      );
    }

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Store updated successfully' : 'Store created successfully',
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
        title: Text(isEditing ? 'Edit Store' : 'Add Store'),
        actions: [
          Consumer<StoreProvider>(
            builder: (context, storeProvider, child) {
              return TextButton(
                onPressed: storeProvider.isLoading ? null : _saveStore,
                child: storeProvider.isLoading
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
      body: Consumer2<StoreProvider, CompanyProvider>(
        builder: (context, storeProvider, companyProvider, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                if (storeProvider.errorMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
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
                            storeProvider.errorMessage!,
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
                  'Store Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _nameController,
                  label: 'Store Name',
                  hint: 'Enter store name',
                  prefixIcon: Icons.store,
                  validator: (value) => _validateRequired(value, 'Store name'),
                ),
                SizedBox(height: 16.h),

                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<Company>(
                          value: _selectedCompany,
                          decoration: InputDecoration(
                            hintText: 'Select company',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          items: companyProvider.companies.map((company) {
                            return DropdownMenuItem(
                              value: company,
                              child: Text(company.name),
                            );
                          }).toList(),
                          onChanged: (Company? value) {
                            setState(() {
                              _selectedCompany = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a company';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Enter store description',
                  prefixIcon: Icons.description,
                  maxLines: 3,
                ),
                SizedBox(height: 24.h),

                Text(
                  'Address Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Enter complete address',
                  prefixIcon: Icons.location_on,
                  maxLines: 2,
                  validator: (value) => _validateRequired(value, 'Address'),
                ),
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _cityController,
                        label: 'City',
                        hint: 'Enter city',
                        prefixIcon: Icons.location_city,
                        validator: (value) => _validateRequired(value, 'City'),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: CustomTextField(
                        controller: _stateController,
                        label: 'State',
                        hint: 'Enter state',
                        prefixIcon: Icons.map,
                        validator: (value) => _validateRequired(value, 'State'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                PinCodeInputField(
                  pincodeController: _pincodeController,
                  cityController: _cityController,
                  stateController: _stateController,
                  label: 'Pincode',
                  hint: 'Enter 6-digit pincode',
                  validator: _validatePincode,
                  onPinCodeFound: (data) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Auto-filled: ${data['city']}, ${data['state']}'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),
                SizedBox(height: 24.h),

                Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'Enter phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _emailController,
                  label: 'Email (Optional)',
                  hint: 'Enter email address',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: 24.h),

                Text(
                  'Store Status',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: _isActive 
                            ? AppColors.success.withOpacity(0.1)
                            : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          _isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: _isActive ? AppColors.success : Colors.red.shade600,
                          size: 24.w,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Store Status',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _isActive 
                                ? 'Store is currently active and operational' 
                                : 'Store is currently inactive and not operational',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        activeColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withOpacity(0.3),
                        inactiveTrackColor: Colors.grey.shade300,
                        inactiveThumbColor: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          );
        },
      ),
    );
  }
}