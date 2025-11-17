import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/models/company.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../pincodes/widgets/pincode_input_field.dart';
import '../providers/company_provider.dart';

class CompanyFormScreen extends StatefulWidget {
  final Company? company;

  const CompanyFormScreen({super.key, this.company});

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankBranchController = TextEditingController();

  bool _isActive = true;

  bool get isEditing => widget.company != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    final company = widget.company!;
    _nameController.text = company.name;
    _descriptionController.text = company.description ?? '';
    _addressController.text = company.address;
    _cityController.text = company.city;
    _stateController.text = company.state;
    _pincodeController.text = company.pincode;
    _phoneController.text = company.phone;
    _emailController.text = company.email;
    _gstinController.text = company.gstin;
    _panController.text = company.pan;
    _bankNameController.text = company.bankName ?? '';
    _bankAccountNumberController.text = company.bankAccountNumber ?? '';
    _bankIfscController.text = company.bankIfsc ?? '';
    _bankBranchController.text = company.bankBranch ?? '';
    _isActive = company.isActive;
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
    _gstinController.dispose();
    _panController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankIfscController.dispose();
    _bankBranchController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
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

  String? _validateGSTIN(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'GSTIN is required';
    }
    if (value.trim().length != 15) {
      return 'GSTIN must be 15 characters';
    }
    return null;
  }

  String? _validatePAN(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PAN is required';
    }
    if (value.trim().length != 10) {
      return 'PAN must be 10 characters';
    }
    return null;
  }

  String? _validateIFSC(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // IFSC is optional
    }
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(value.trim())) {
      return 'Invalid IFSC code format';
    }
    return null;
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final companyProvider = context.read<CompanyProvider>();
    
    bool success;
    if (isEditing) {
      success = await companyProvider.updateCompany(
        id: widget.company!.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        gstin: _gstinController.text.trim(),
        pan: _panController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty
            ? null
            : _bankAccountNumberController.text.trim(),
        bankIfsc: _bankIfscController.text.trim().isEmpty
            ? null
            : _bankIfscController.text.trim(),
        bankBranch: _bankBranchController.text.trim().isEmpty
            ? null
            : _bankBranchController.text.trim(),
        isActive: _isActive,
      );
    } else {
      success = await companyProvider.createCompany(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        gstin: _gstinController.text.trim(),
        pan: _panController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty
            ? null
            : _bankAccountNumberController.text.trim(),
        bankIfsc: _bankIfscController.text.trim().isEmpty
            ? null
            : _bankIfscController.text.trim(),
        bankBranch: _bankBranchController.text.trim().isEmpty
            ? null
            : _bankBranchController.text.trim(),
        isActive: _isActive,
      );
    }

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Company updated successfully' : 'Company created successfully',
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
        title: Text(isEditing ? 'Edit Company' : 'Add Company'),
        actions: [
          Consumer<CompanyProvider>(
            builder: (context, companyProvider, child) {
              return TextButton(
                onPressed: companyProvider.isLoading ? null : _saveCompany,
                child: companyProvider.isLoading
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
      body: Consumer<CompanyProvider>(
        builder: (context, companyProvider, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                if (companyProvider.errorMessage != null) ...[
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
                            companyProvider.errorMessage!,
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
                  'Company Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _nameController,
                  label: 'Company Name',
                  hint: 'Enter company name',
                  prefixIcon: Icons.business,
                  validator: (value) => _validateRequired(value, 'Company name'),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Enter company description',
                  prefixIcon: Icons.description,
                  maxLines: 3,
                ),
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Icon(
                      Icons.toggle_on,
                      color: AppColors.primary,
                      size: 24.w,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Company Status',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                      activeColor: AppColors.success,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: _isActive ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
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
                    // Show a subtle confirmation that location was auto-filled
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
                  label: 'Email',
                  hint: 'Enter email address',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: 24.h),

                Text(
                  'Tax Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _gstinController,
                  label: 'GSTIN',
                  hint: 'Enter 15-digit GSTIN',
                  prefixIcon: Icons.receipt_long,
                  validator: _validateGSTIN,
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _panController,
                  label: 'PAN',
                  hint: 'Enter 10-digit PAN',
                  prefixIcon: Icons.credit_card,
                  validator: _validatePAN,
                ),
                SizedBox(height: 24.h),

                Text(
                  'Bank Account Details (Optional)',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _bankNameController,
                  label: 'Bank Name',
                  hint: 'Enter bank name',
                  prefixIcon: Icons.account_balance,
                ),
                SizedBox(height: 16.h),

                CustomTextField(
                  controller: _bankAccountNumberController,
                  label: 'Account Number',
                  hint: 'Enter account number',
                  prefixIcon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _bankIfscController,
                        label: 'IFSC Code',
                        hint: 'e.g. SBIN0001234',
                        prefixIcon: Icons.code,
                        validator: _validateIFSC,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: CustomTextField(
                        controller: _bankBranchController,
                        label: 'Branch',
                        hint: 'Enter branch name',
                        prefixIcon: Icons.business,
                      ),
                    ),
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
}