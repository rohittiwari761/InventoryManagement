import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/models/company.dart';
import '../providers/company_provider.dart';
import 'company_form_screen.dart';

class CompanyDetailScreen extends StatelessWidget {
  final Company company;

  const CompanyDetailScreen({super.key, required this.company});

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
                          company.name,
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
                          'GSTIN: ${company.gstin}',
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
                              builder: (context) => CompanyFormScreen(company: company),
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
                            Text('Edit Company'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 20, color: Colors.red.shade600),
                            const SizedBox(width: 12),
                            Text('Delete Company', style: TextStyle(color: Colors.red.shade600)),
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
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompanyHeader(),
            SizedBox(height: 20.h),
            
            // Quick Info Cards
            _buildQuickInfoCards(),
            SizedBox(height: 20.h),
            
            _buildInfoSection(
              'Company Information',
              Icons.business_rounded,
              [
                _buildDetailRow('Company Name', company.name),
                if (company.description?.isNotEmpty == true)
                  _buildDetailRow('Description', company.description!),
              ],
            ),
            SizedBox(height: 16.h),
            
            _buildInfoSection(
              'Address & Location',
              Icons.location_on_rounded,
              [
                _buildDetailRow('Full Address', company.address),
                _buildDetailRow('City', company.city),
                _buildDetailRow('State', company.state),
                _buildDetailRow('Pincode', company.pincode),
              ],
            ),
            SizedBox(height: 16.h),
            
            _buildInfoSection(
              'Contact Details',
              Icons.contact_phone_rounded,
              [
                _buildDetailRow('Phone Number', company.phone),
                _buildDetailRow('Email Address', company.email),
              ],
            ),
            SizedBox(height: 16.h),
            
            _buildInfoSection(
              'Tax & Legal Information',
              Icons.receipt_long_rounded,
              [
                _buildDetailRow('GSTIN', company.gstin, isHighlighted: true),
                _buildDetailRow('PAN Number', company.pan),
              ],
            ),
            SizedBox(height: 16.h),

            // Bank Account Details Section
            if (company.bankName != null ||
                company.bankAccountNumber != null ||
                company.bankIfsc != null ||
                company.bankBranch != null)
              _buildInfoSection(
                'Bank Account Details',
                Icons.account_balance_rounded,
                [
                  if (company.bankName != null)
                    _buildDetailRow('Bank Name', company.bankName!),
                  if (company.bankAccountNumber != null)
                    _buildDetailRow('Account Number', company.bankAccountNumber!),
                  if (company.bankIfsc != null)
                    _buildDetailRow('IFSC Code', company.bankIfsc!, isHighlighted: true),
                  if (company.bankBranch != null)
                    _buildDetailRow('Branch', company.bankBranch!),
                ],
              )
            else
              _buildInfoSection(
                'Bank Account Details',
                Icons.account_balance_rounded,
                [
                  _buildNoDataRow('No bank details added'),
                ],
              ),
            SizedBox(height: 16.h),

            _buildInfoSection(
              'System Information',
              Icons.info_outline_rounded,
              [
                _buildDetailRow(
                  'Status', 
                  company.isActive ? 'Active' : 'Inactive',
                  statusColor: company.isActive ? Colors.green.shade600 : Colors.red.shade600,
                ),
                _buildDetailRow('Created On', _formatDate(company.createdAt)),
                _buildDetailRow('Last Modified', _formatDate(company.updatedAt)),
              ],
            ),
            
            SizedBox(height: 100.h), // Extra space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompanyFormScreen(company: company),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Edit Company'),
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business,
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
                    company.name,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: company.isActive
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      company.isActive ? AppStrings.active : AppStrings.inactive,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: company.isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
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
            company.city,
            Icons.location_city_rounded,
            Colors.blue,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildInfoCard(
            'GSTIN',
            company.gstin.length > 8 ? '${company.gstin.substring(0, 8)}...' : company.gstin,
            Icons.receipt_long_rounded,
            Colors.green,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildInfoCard(
            'State',
            company.state,
            Icons.map_rounded,
            Colors.purple,
          ),
        ),
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

  Widget _buildNoDataRow(String message) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Company'),
          content: Text(
            'Are you sure you want to delete "${company.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            Consumer<CompanyProvider>(
              builder: (context, companyProvider, child) {
                return TextButton(
                  onPressed: companyProvider.isLoading
                      ? null
                      : () async {
                          final success = await companyProvider.deleteCompany(company.id);
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Company deleted successfully'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: companyProvider.isLoading
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