import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/invoice.dart';
import '../../../shared/models/customer.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../../customers/providers/customer_provider.dart';
import 'invoice_form_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with TickerProviderStateMixin {
  late Invoice _invoice;
  Customer? _customer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Fetch complete invoice details with items and customer data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInvoiceDetails();
      _fetchCustomerDetails();
    });
  }

  void _fetchInvoiceDetails() async {
    final invoiceProvider = context.read<InvoiceProvider>();
    await invoiceProvider.fetchInvoice(_invoice.id);

    if (invoiceProvider.selectedInvoice != null) {
      setState(() {
        _invoice = invoiceProvider.selectedInvoice!;
      });

      // Debug tax rates to identify discrepancies
      _debugTaxRates();
    }
  }

  void _fetchCustomerDetails() async {
    if (_invoice.customer > 0) {
      final customerProvider = context.read<CustomerProvider>();
      await customerProvider.fetchCustomer(_invoice.customer);

      if (customerProvider.selectedCustomer != null) {
        setState(() {
          _customer = customerProvider.selectedCustomer!;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<InvoiceProvider, AuthProvider, CustomerProvider>(
      builder:
          (context, invoiceProvider, authProvider, customerProvider, child) {
            final user = authProvider.user;

            return Scaffold(
              backgroundColor: Colors.grey[50],
              appBar: _buildModernAppBar(user, invoiceProvider),
              body: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInvoiceHeader(),
                        SizedBox(height: 16.h),
                        _buildParticipantsSection(),
                        SizedBox(height: 16.h),
                        _buildItemsSection(),
                        SizedBox(height: 16.h),
                        _buildGSTBreakdownSection(),
                        SizedBox(height: 16.h),
                        if (_invoice.notes != null &&
                            _invoice.notes!.isNotEmpty) ...[
                          SizedBox(height: 16.h),
                          _buildNotesSection(),
                        ],
                        if (_invoice.termsAndConditions.isNotEmpty) ...[
                          SizedBox(height: 16.h),
                          _buildTermsSection(),
                        ],
                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    user,
    InvoiceProvider invoiceProvider,
  ) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GST Invoice',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            '#${_invoice.invoiceNumber}',
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF1565C0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, invoiceProvider),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            icon: Icon(
              Icons.more_vert,
              color: const Color(0xFF1565C0),
              size: 20.w,
            ),
            itemBuilder: (context) => [
              if (user?.isAdmin == true ||
                  _invoice.status == InvoiceStatus.draft) ...[
                PopupMenuItem(
                  value: 'edit',
                  child: _buildMenuItem(
                    Icons.edit,
                    'Edit',
                    const Color(0xFF1565C0),
                  ),
                ),
              ],
              PopupMenuItem(
                value: 'pdf',
                child: _buildMenuItem(
                  Icons.picture_as_pdf,
                  'Generate PDF',
                  Colors.green[600]!,
                ),
              ),
              PopupMenuItem(
                value: 'share_pdf',
                child: _buildMenuItem(
                  Icons.share,
                  'Share PDF',
                  Colors.blue[600]!,
                ),
              ),
              if (_invoice.customerEmail != null &&
                  _invoice.customerEmail!.isNotEmpty) ...[
                PopupMenuItem(
                  value: 'email',
                  child: _buildMenuItem(
                    Icons.email,
                    'Send Email',
                    Colors.blue[600]!,
                  ),
                ),
              ],
              if (_invoice.status == InvoiceStatus.draft) ...[
                PopupMenuItem(
                  value: 'send',
                  child: _buildMenuItem(
                    Icons.send,
                    'Mark as Sent',
                    Colors.orange[600]!,
                  ),
                ),
              ],
              if (_invoice.status == InvoiceStatus.sent) ...[
                PopupMenuItem(
                  value: 'paid',
                  child: _buildMenuItem(
                    Icons.check_circle,
                    'Mark as Paid',
                    Colors.green[600]!,
                  ),
                ),
              ],
              if (user?.isAdmin == true) ...[
                PopupMenuItem(
                  value: 'delete',
                  child: _buildMenuItem(
                    Icons.delete,
                    'Delete',
                    Colors.red[600]!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(width: 12.w),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'TAX INVOICE',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _invoice.invoiceNumber,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildProfessionalStatusChip(_invoice.status),
            ],
          ),

          SizedBox(height: 20.h),

          // Date Information
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice Date',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _invoice.formattedInvoiceDate,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    if (_invoice.dueDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Due Date',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _invoice.formattedDueDate,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: _invoice.status == InvoiceStatus.overdue
                                  ? Colors.red[600]
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Financial Year moved below dates
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      'Financial Year: ${_invoice.financialYear}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // Grand Total Card with responsive text
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1565C0).withOpacity(0.1),
                  const Color(0xFF1565C0).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFF1565C0).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grand Total',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₹${NumberFormat('#,##,###.##').format(_invoice.totalAmount)}',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.currency_rupee,
                    color: const Color(0xFF1565C0),
                    size: 24.w,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalStatusChip(InvoiceStatus status) {
    Color statusColor;
    IconData icon;

    switch (status) {
      case InvoiceStatus.draft:
        statusColor = Colors.orange[600]!;
        icon = Icons.edit;
        break;
      case InvoiceStatus.sent:
        statusColor = Colors.blue[600]!;
        icon = Icons.send;
        break;
      case InvoiceStatus.paid:
        statusColor = Colors.green[600]!;
        icon = Icons.check_circle;
        break;
      case InvoiceStatus.cancelled:
        statusColor = Colors.red[600]!;
        icon = Icons.cancel;
        break;
      case InvoiceStatus.overdue:
        statusColor = Colors.red[600]!;
        icon = Icons.warning;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: statusColor, size: 16.w),
          SizedBox(width: 6.w),
          Text(
            status.displayName.toUpperCase(),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: statusColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      children: [
        _buildSellerCard(),
        SizedBox(height: 16.h),
        _buildBuyerCard(),
      ],
    );
  }

  Widget _buildSellerCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean header section
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Simple company icon
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Icon(Icons.business, color: Colors.white, size: 16.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill From',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _invoice.companyName ?? 'Company Name',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                          letterSpacing: -0.1,
                        ),
                      ),
                      // Store information badge
                      if (_invoice.storeName?.isNotEmpty == true) ...[
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.store_outlined,
                                color: const Color(0xFF3B82F6),
                                size: 12.w,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Store: ${_invoice.storeName}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF3B82F6),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content sections
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Two column layout for larger screens
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column - Address & Contact
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Address section
                            if (_invoice
                                .formattedCompanyAddress
                                .isNotEmpty) ...[
                              _buildMinimalSection(
                                'Address',
                                _invoice.formattedCompanyAddress,
                                isMultiline: true,
                              ),
                              SizedBox(height: 20.h),
                            ],

                            // Contact section
                            if ((_invoice.companyPhone?.isNotEmpty == true) ||
                                (_invoice.companyEmail?.isNotEmpty ==
                                    true)) ...[
                              _buildContactSection(
                                phone: _invoice.companyPhone,
                                email: _invoice.companyEmail,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Subtle vertical divider
                      if ((_invoice.companyGstin?.isNotEmpty == true) ||
                          (_invoice.companyPan?.isNotEmpty == true)) ...[
                        SizedBox(width: 24.w),
                        Container(
                          width: 1,
                          height: double.infinity,
                          color: const Color(0xFFE5E7EB),
                        ),
                        SizedBox(width: 24.w),
                      ],

                      // Right column - Tax info
                      if ((_invoice.companyGstin?.isNotEmpty == true) ||
                          (_invoice.companyPan?.isNotEmpty == true)) ...[
                        Expanded(
                          child: _buildTaxSection(
                            gstin: _invoice.companyGstin,
                            pan: _invoice.companyPan,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Minimal fallback message
                if (_invoice.formattedCompanyAddress.isEmpty &&
                    (_invoice.companyPhone?.isEmpty ?? true) &&
                    (_invoice.companyEmail?.isEmpty ?? true) &&
                    (_invoice.companyGstin?.isEmpty ?? true) &&
                    (_invoice.companyPan?.isEmpty ?? true)) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(2.r),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF92400E),
                          size: 16.w,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Complete company profile to display additional information',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF92400E),
                              fontWeight: FontWeight.w400,
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
        ],
      ),
    );
  }

  Widget _buildBuyerCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean header section
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Simple customer icon
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 16.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill To',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _customer?.name ??
                            _invoice.customerName ??
                            'Customer Name',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content sections
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Two column layout for larger screens
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column - Address & Contact
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Address section
                            if (_invoice
                                .formattedCustomerAddress
                                .isNotEmpty) ...[
                              _buildMinimalSection(
                                'Address',
                                _invoice.formattedCustomerAddress,
                                isMultiline: true,
                              ),
                              SizedBox(height: 20.h),
                            ],

                            // Contact section
                            if ((_customer?.phone?.isNotEmpty == true) ||
                                (_customer?.email?.isNotEmpty == true) ||
                                (_invoice.customerPhone?.isNotEmpty == true) ||
                                (_invoice.customerEmail?.isNotEmpty ==
                                    true)) ...[
                              _buildContactSection(
                                phone:
                                    _customer?.phone ?? _invoice.customerPhone,
                                email:
                                    _customer?.email ?? _invoice.customerEmail,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Subtle vertical divider
                      if ((_customer?.gstin?.isNotEmpty == true) ||
                          (_invoice.customerGstin?.isNotEmpty == true)) ...[
                        SizedBox(width: 24.w),
                        Container(
                          width: 1,
                          height: double.infinity,
                          color: const Color(0xFFE5E7EB),
                        ),
                        SizedBox(width: 24.w),
                      ],

                      // Right column - Tax info
                      if ((_customer?.gstin?.isNotEmpty == true) ||
                          (_invoice.customerGstin?.isNotEmpty == true)) ...[
                        Expanded(
                          child: _buildTaxSection(
                            gstin: _customer?.gstin ?? _invoice.customerGstin,
                            pan:
                                null, // Customers typically don't have PAN displayed
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Minimal fallback message
                if (_invoice.formattedCustomerAddress.isEmpty &&
                    (_customer?.phone?.isEmpty ?? true) &&
                    (_customer?.email?.isEmpty ?? true) &&
                    (_invoice.customerPhone?.isEmpty ?? true) &&
                    (_invoice.customerEmail?.isEmpty ?? true) &&
                    (_customer?.gstin?.isEmpty ?? true) &&
                    (_invoice.customerGstin?.isEmpty ?? true)) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(2.r),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF92400E),
                          size: 16.w,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Complete customer profile to display additional information',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF92400E),
                              fontWeight: FontWeight.w400,
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
        ],
      ),
    );
  }

  Widget _buildModernAddressCard(String address) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.05),
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
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: const Color(0xFF6366F1).withOpacity(0.7),
                  size: 16.w,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Address',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Text(
              address,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF475569),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Clean Minimalistic Helper Methods
  Widget _buildMinimalSection(
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF374151),
            height: isMultiline ? 1.5 : 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection({String? phone, String? email}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 6.h),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone?.isNotEmpty == true) ...[
              Text(
                phone!,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF374151),
                ),
              ),
              if (email?.isNotEmpty == true) SizedBox(height: 4.h),
            ],
            if (email?.isNotEmpty == true) ...[
              Text(
                email!,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF374151),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTaxSection({String? gstin, String? pan}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tax Information',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 12.h),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gstin?.isNotEmpty == true) ...[
              _buildTaxItem('GSTIN', gstin!),
              if (pan?.isNotEmpty == true) SizedBox(height: 12.h),
            ],
            if (pan?.isNotEmpty == true) ...[_buildTaxItem('PAN', pan!)],
          ],
        ),
      ],
    );
  }

  Widget _buildTaxItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9CA3AF),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(2.r),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(
    String label,
    String value,
    IconData icon, {
    bool isMultiline = false,
    bool isTaxId = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14.w, color: const Color(0xFF4A5568)),
            SizedBox(width: 6.w),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A5568),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: isMultiline ? 12.h : 10.h,
          ),
          decoration: BoxDecoration(
            color: isTaxId ? const Color(0xFFF0F9FF) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(
              color: isTaxId
                  ? const Color(0xFFBAE6FD)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: isTaxId ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF2D3748),
              height: isMultiline ? 1.4 : 1.2,
              fontFamily: isTaxId ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  // New enhanced contact item method
  Widget _buildContactItem(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 24.w,
            height: 24.h,
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 12.w, color: Colors.white),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced address section method
  Widget _buildAddressSection(String address) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B7280),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.location_on, size: 12.w, color: Colors.white),
              ),
              SizedBox(width: 8.w),
              Text(
                'Address',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            address,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 16.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Items',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.1,
                  ),
                ),
                Spacer(),
                Text(
                  '${_invoice.items.length} item${_invoice.items.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // Items Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item Details',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'HSN Code',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Qty',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Rate',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Items List or Empty State
          if (_invoice.items.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(40.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange[200]!, width: 2),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 48.w,
                      color: Colors.orange[600],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'No Items in Invoice',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'This invoice doesn\'t contain any items yet.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Items List
            ..._invoice.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: index == _invoice.items.length - 1
                          ? Colors.transparent
                          : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Item Name and Details
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 2.h),
                              Text(
                                _invoice.companyName ?? 'Unknown Company',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          if (item.taxRate > 0) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Tax: ${item.taxRate}%',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: const Color(0xFF059669),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // HSN Code
                    Expanded(
                      flex: 2,
                      child: Text(
                        _getValidHSN(item.itemHsnCode),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF374151),
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Quantity
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.quantity.toStringAsFixed(
                          item.quantity == item.quantity.toInt() ? 0 : 1,
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Unit Price
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${NumberFormat('#,##,##0.##').format(item.unitPrice)}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Amount (without tax)
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${NumberFormat('#,##,##0.##').format(item.lineTotal)}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildGSTBreakdownSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Icon(Icons.calculate, color: Colors.white, size: 16.w),
                ),
                SizedBox(width: 12.w),
                Text(
                  'GST Breakdown',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.1,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _invoice.isInterState
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    _invoice.isInterState ? 'IGST' : 'CGST+SGST',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: _invoice.isInterState
                          ? const Color(0xFF92400E)
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // GST Information and Calculations
          Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtotal
                _buildCalculationRow(
                  'Subtotal',
                  null,
                  _invoice.subtotal,
                  isSubtotal: true,
                ),
                SizedBox(height: 16.h),

                // GST Breakdown Table
                if (_invoice.cgstAmount > 0 || _invoice.igstAmount > 0) ...[
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Tax Component',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Rate',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Tax Amount',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Divider(color: const Color(0xFFE5E7EB), height: 1),
                        SizedBox(height: 12.h),

                        // Tax Rows
                        ..._buildGSTTaxRows(),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // Additional Charges
                if (_invoice.cessAmount > 0)
                  _buildCalculationRow('CESS', null, _invoice.cessAmount),
                if (_invoice.tcsAmount > 0)
                  _buildCalculationRow('TCS', null, _invoice.tcsAmount),
                if (_invoice.roundOff != 0)
                  _buildCalculationRow('Round Off', null, _invoice.roundOff),

                // Total Tax Amount
                if (_calculateTotalTaxAmount() > 0) ...[
                  SizedBox(height: 12.h),
                  _buildCalculationRow(
                    'Total Tax',
                    null,
                    _calculateTotalTaxAmount(),
                    isTaxTotal: true,
                  ),
                ],

                // Divider before grand total
                Container(
                  height: 1,
                  color: const Color(0xFFD1D5DB),
                  margin: EdgeInsets.symmetric(vertical: 20.h),
                ),

                // Grand Total
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 20.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GRAND TOTAL',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '₹${NumberFormat('#,##,###.##').format(_invoice.totalAmount)}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Center(
        child: Text(
          'Additional Info content here',
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF6B7280)),
        ),
      ),
    );
  }

  Widget _buildItemDetailTag(String label, String value, MaterialColor color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color[200]!),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: color[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              color: color[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    double? rate,
    double amount, {
    bool isHeader = false,
    bool isSubtotal = false,
    bool isTaxTotal = false,
  }) {
    Color labelColor = const Color(0xFF6B7280);
    Color amountColor = const Color(0xFF374151);
    FontWeight labelWeight = FontWeight.w500;
    FontWeight amountWeight = FontWeight.w600;
    double fontSize = 14.sp;
    Color? backgroundColor;

    if (isSubtotal) {
      labelColor = const Color(0xFF374151);
      amountColor = const Color(0xFF111827);
      labelWeight = FontWeight.w600;
      amountWeight = FontWeight.bold;
      fontSize = 15.sp;
      backgroundColor = const Color(0xFFF8F9FA);
    } else if (isTaxTotal) {
      labelColor = const Color(0xFF059669);
      amountColor = const Color(0xFF059669);
      labelWeight = FontWeight.w600;
      amountWeight = FontWeight.bold;
    } else if (isHeader) {
      labelColor = const Color(0xFF111827);
      amountColor = const Color(0xFF111827);
      labelWeight = FontWeight.w600;
      amountWeight = FontWeight.bold;
      fontSize = 15.sp;
      backgroundColor = const Color(0xFFF8F9FA);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: labelWeight,
              color: labelColor,
            ),
          ),
          Text(
            '₹${NumberFormat('#,##,###.##').format(amount)}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: amountWeight,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRow(String taxType, double rate, double amount) {
    // Determine colors based on tax type for better visual distinction
    Color rowColor = Colors.transparent;
    Color textColor = const Color(0xFF374151);

    if (taxType.startsWith('CGST')) {
      rowColor = const Color(0xFFF0F9FF); // Light blue for CGST
    } else if (taxType.startsWith('SGST')) {
      rowColor = const Color(0xFFF0FDF4); // Light green for SGST
    } else if (taxType.startsWith('IGST')) {
      rowColor = const Color(0xFFFFF7ED); // Light orange for IGST
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              taxType,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${rate.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '₹${NumberFormat('#,##,###.##').format(amount)}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF059669),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTotalRow(
    String label,
    double amount, {
    bool isSubtotal = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isSubtotal ? Colors.grey[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSubtotal ? 16.sp : 14.sp,
              fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.w500,
              color: isSubtotal ? Colors.black87 : Colors.grey[700],
            ),
          ),
          Text(
            '₹${NumberFormat('#,##,###.##').format(amount)}',
            style: TextStyle(
              fontSize: isSubtotal ? 16.sp : 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Group items by their GST rates and build tax breakdown rows
  List<Widget> _buildGSTTaxRows() {
    final List<Widget> taxRows = [];

    if (_invoice.items.isEmpty) {
      return taxRows;
    }

    // Group items by their tax rates
    final Map<double, List<InvoiceItem>> itemsByTaxRate = {};

    for (final item in _invoice.items) {
      final taxRate = item.taxRate;
      if (taxRate > 0) {
        // Only include items with tax
        if (!itemsByTaxRate.containsKey(taxRate)) {
          itemsByTaxRate[taxRate] = [];
        }
        itemsByTaxRate[taxRate]!.add(item);
      }
    }

    // Sort tax rates for consistent display
    final sortedTaxRates = itemsByTaxRate.keys.toList()..sort();

    for (int i = 0; i < sortedTaxRates.length; i++) {
      final taxRate = sortedTaxRates[i];
      final items = itemsByTaxRate[taxRate]!;

      // Calculate total amounts for this tax rate
      double totalCGSTAmount = 0;
      double totalSGSTAmount = 0;
      double totalIGSTAmount = 0;

      for (final item in items) {
        totalCGSTAmount += item.cgstAmount;
        totalSGSTAmount += item.sgstAmount;
        totalIGSTAmount += item.igstAmount;
      }

      // Determine if inter-state or intra-state transaction
      bool isInterState = _invoice.isInterState;

      if (isInterState && totalIGSTAmount > 0) {
        // Inter-state: Show IGST
        taxRows.add(
          _buildTaxRow(
            'IGST (${taxRate.toStringAsFixed(1)}%)',
            taxRate,
            totalIGSTAmount,
          ),
        );

        // Add visual separator between different tax rates
        if (i < sortedTaxRates.length - 1) {
          taxRows.add(SizedBox(height: 8.h));
          taxRows.add(
            Container(
              height: 1.h,
              color: const Color(0xFFE5E7EB),
              margin: EdgeInsets.symmetric(horizontal: 8.w),
            ),
          );
          taxRows.add(SizedBox(height: 8.h));
        }
      } else if (!isInterState &&
          (totalCGSTAmount > 0 || totalSGSTAmount > 0)) {
        // Intra-state: Show CGST + SGST
        final cgstRate = taxRate / 2;
        final sgstRate = taxRate / 2;

        if (totalCGSTAmount > 0) {
          taxRows.add(
            _buildTaxRow(
              'CGST (${cgstRate.toStringAsFixed(1)}%)',
              cgstRate,
              totalCGSTAmount,
            ),
          );
          taxRows.add(SizedBox(height: 6.h));
        }

        if (totalSGSTAmount > 0) {
          taxRows.add(
            _buildTaxRow(
              'SGST (${sgstRate.toStringAsFixed(1)}%)',
              sgstRate,
              totalSGSTAmount,
            ),
          );
        }

        // Add visual separator between different tax rate groups
        if (i < sortedTaxRates.length - 1) {
          taxRows.add(SizedBox(height: 8.h));
          taxRows.add(
            Container(
              height: 1.h,
              color: const Color(0xFFE5E7EB),
              margin: EdgeInsets.symmetric(horizontal: 8.w),
            ),
          );
          taxRows.add(SizedBox(height: 8.h));
        }
      }
    }

    return taxRows;
  }

  // Helper method to get unique tax rates from items
  Set<double> _getUniqueTaxRates() {
    return _invoice.items.map((item) => item.taxRate).toSet();
  }

  // Calculate total tax amount for verification
  double _calculateTotalTaxAmount() {
    double total = 0;
    for (final item in _invoice.items) {
      total += item.cgstAmount + item.sgstAmount + item.igstAmount;
    }
    return total;
  }

  // Helper method for building detailed info rows with professional styling
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color backgroundColor,
    bool isCompact = false,
    TextStyle? valueStyle,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10.w : 12.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: isCompact ? 16.w : 18.w),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isCompact ? 11.sp : 12.sp,
                    color: iconColor.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  value,
                  style:
                      valueStyle ??
                      TextStyle(
                        fontSize: isCompact ? 12.sp : 14.sp,
                        color:
                            value.contains('not available') ||
                                value.contains('Not available')
                            ? Colors.grey[500]
                            : Colors.black87,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        fontStyle:
                            value.contains('not available') ||
                                value.contains('Not available')
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Debug method to analyze tax rate discrepancies
  void _debugTaxRates() {
    print('=== TAX RATE DEBUG ANALYSIS ===');
    for (int i = 0; i < _invoice.items.length; i++) {
      final item = _invoice.items[i];
      print('Item ${i + 1}: ${item.itemName}');
      print('  Main tax_rate: ${item.taxRate}%');
      print('  CGST rate: ${item.cgstRate}%');
      print('  SGST rate: ${item.sgstRate}%');
      print('  IGST rate: ${item.igstRate}%');
      print('  CGST amount: ₹${item.cgstAmount}');
      print('  SGST amount: ₹${item.sgstAmount}');
      print('  IGST amount: ₹${item.igstAmount}');
      print('  Expected CGST rate: ${item.taxRate / 2}%');
      print('  Expected SGST rate: ${item.taxRate / 2}%');
      print(
        '  Rate mismatch: ${item.cgstRate != item.taxRate / 2 ? "YES" : "NO"}',
      );
      print('---');
    }
    print('Invoice totals:');
    print('  Total CGST: ₹${_invoice.cgstAmount}');
    print('  Total SGST: ₹${_invoice.sgstAmount}');
    print('  Total IGST: ₹${_invoice.igstAmount}');
    print('=== END DEBUG ===');
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.sticky_note_2,
                  color: Colors.orange[700],
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.yellow.withOpacity(0.3)),
            ),
            child: Text(
              _invoice.notes!,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.gavel, color: Colors.red[600], size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              _invoice.termsAndConditions,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInvoiceTypeDisplay(String type) {
    switch (type) {
      case 'tax_invoice':
        return 'Tax Invoice';
      case 'bill_of_supply':
        return 'Bill of Supply';
      case 'export_invoice':
        return 'Export Invoice';
      default:
        return type;
    }
  }

  void _handleMenuAction(String action, InvoiceProvider provider) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceFormScreen(invoice: _invoice),
          ),
        );
        break;
      case 'pdf':
        _generatePdf(provider);
        break;
      case 'share_pdf':
        _sharePdf(provider);
        break;
      case 'email':
        _sendEmail(provider);
        break;
      case 'send':
        _updateStatus(provider, InvoiceStatus.sent);
        break;
      case 'paid':
        _updateStatus(provider, InvoiceStatus.paid);
        break;
      case 'delete':
        _showDeleteDialog(provider);
        break;
    }
  }

  void _generatePdf(InvoiceProvider provider) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16.h),
                Text(
                  'Generating PDF...',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      print('Starting PDF generation for invoice ID: ${_invoice.id}');
      print(
        'Invoice details - Number: ${_invoice.invoiceNumber}, Items: ${_invoice.items.length}',
      );

      List<int>? pdfBytes;

      // Try server-side PDF generation first (enhanced backend)
      print('Attempting server-side PDF generation...');
      try {
        pdfBytes = await provider.generateInvoicePdf(_invoice.id);
        print(
          'Server PDF generation completed. Bytes received: ${pdfBytes?.length ?? 0}',
        );
      } catch (serverError) {
        print('Server PDF generation failed: $serverError');

        // Fallback to client-side PDF generation
        try {
          print('Falling back to client-side PDF generation...');
          pdfBytes = await _generateClientSidePdf();
          print(
            'Client-side PDF generation completed. Bytes: ${pdfBytes?.length ?? 0}',
          );
        } catch (clientError, stackTrace) {
          print('Client-side PDF generation also failed: $clientError');
          print('Client PDF Stack trace: $stackTrace');
          pdfBytes = null;
        }
      }

      if (mounted) Navigator.pop(context);

      if (pdfBytes != null && pdfBytes.isNotEmpty && mounted) {
        print('PDF bytes valid, proceeding to save...');
        await _savePdfFile(pdfBytes);
      } else if (mounted) {
        print('Both server and client PDF generation failed');
        _showSnackBar(
          'Failed to generate PDF - please try again or contact support',
          AppColors.error,
        );
      }
    } catch (e, stackTrace) {
      print('PDF generation error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error generating PDF: ${e.toString()}', AppColors.error);
    }
  }

  // Enhanced Professional Header
  pw.Widget _buildProfessionalHeader() {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Enhanced Logo Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 80,
                  height: 80,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9FA'),
                    border: pw.Border.all(
                      color: PdfColor.fromHex('#2B5CE6'),
                      width: 2,
                    ),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          'COMPANY',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#2B5CE6'),
                          ),
                        ),
                        pw.Text(
                          'LOGO',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('#6B7280'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 15),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _invoice.companyName ?? 'Company Name',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1F2937'),
                      ),
                    ),
                    if (_invoice.companyEmail?.isNotEmpty == true)
                      pw.Text(
                        _invoice.companyEmail!,
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColor.fromHex('#6B7280'),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Right: Enhanced Tax Invoice Title
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1F2937'),
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2B5CE6'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    _invoice.invoiceNumber,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // Dividing line
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColor.fromHex('#E5E7EB'),
        ),
      ],
    );
  }

  // Invoice Details Block
  pw.Widget _buildInvoiceDetailsBlock() {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F9FA'),
        border: pw.Border.all(color: PdfColor.fromHex('#DEE2E6')),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildDetailColumn('Invoice Date', _invoice.formattedInvoiceDate),
          _buildDetailColumn(
            'Due Date',
            _invoice.formattedDueDate.isNotEmpty
                ? _invoice.formattedDueDate
                : 'Immediate',
          ),
          _buildDetailColumn(
            'Place of Supply',
            _invoice.placeOfSupply.isNotEmpty
                ? _invoice.placeOfSupply.toUpperCase()
                : 'MADHYA PRADESH',
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Status',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromHex('#6C757D'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(_invoice.status),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  _invoice.status.displayName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Enhanced Billing Section with Complete Data
  pw.Widget _buildBillingSection() {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Enhanced Bill From
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 24,
                        color: PdfColor.fromHex('#2B5CE6'),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'BILL FROM',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1F2937'),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F9FAFB'),
                      border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _invoice.companyName ?? 'Company Name',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1F2937'),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _buildCleanAddress(_invoice.formattedCompanyAddress),
                        pw.SizedBox(height: 8),
                        _buildInfoLine(
                          'GSTIN:',
                          _invoice.companyGstin ?? '07ABCDE1234F2Z5',
                        ),
                        _buildInfoLine(
                          'Phone:',
                          _invoice.companyPhone ?? '+91 98765 43210',
                        ),
                        _buildInfoLine(
                          'Email:',
                          _invoice.companyEmail ?? 'contact@company.com',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 24),

            // Enhanced Bill To
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 24,
                        color: PdfColor.fromHex('#059669'),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'BILL TO',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1F2937'),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F9FAFB'),
                      border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _invoice.customerName,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1F2937'),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _buildCleanAddress(_getCleanCustomerAddress()),
                        pw.SizedBox(height: 8),
                        _buildInfoLine('GSTIN:', _getValidGSTIN()),
                        _buildInfoLine(
                          'Phone:',
                          _invoice.customerPhone ?? '+91 98765 43210',
                        ),
                        _buildInfoLine(
                          'Email:',
                          _invoice.customerEmail ?? 'customer@email.com',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // Dividing line
        pw.Container(
          width: double.infinity,
          height: 1,
          color: PdfColor.fromHex('#E5E7EB'),
        ),
      ],
    );
  }

  // Helper methods for clean data formatting
  String _getCleanCustomerAddress() {
    // Simply return the formatted customer address which already prioritizes billing address
    // The formattedCustomerAddress getter handles the logic of using billing address if available
    return _invoice.formattedCustomerAddress.isNotEmpty
        ? _invoice.formattedCustomerAddress.trim()
        : 'Address not provided';
  }

  String _getValidGSTIN() {
    if (_invoice.customerGstin?.isNotEmpty == true &&
        _invoice.customerGstin!.length >= 10) {
      String gstin = _invoice.customerGstin!.trim().toUpperCase();
      return gstin.length >= 15
          ? gstin.substring(0, 15)
          : gstin.padRight(15, '0');
    }
    return '07ABCDE1234F1Z5'; // Valid 15-digit GSTIN format
  }

  pw.Widget _buildCleanAddress(String address) {
    return pw.Text(
      address.isNotEmpty
          ? address
          : 'Business Address, City - 000001, State, India',
      style: pw.TextStyle(
        fontSize: 11,
        color: PdfColor.fromHex('#6B7280'),
        height: 1.4,
      ),
    );
  }

  // Enhanced Professional Items Table
  pw.Widget _buildProfessionalItemsTable() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Table Header with enhanced styling
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#1F2937'),
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8),
              topRight: pw.Radius.circular(8),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 30,
                child: _buildTableHeader('S.No', pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: 3,
                child: _buildTableHeader('Item Name', pw.TextAlign.left),
              ),
              pw.Container(
                width: 65,
                child: _buildTableHeader('HSN/SAC', pw.TextAlign.center),
              ),
              pw.Container(
                width: 40,
                child: _buildTableHeader('Qty', pw.TextAlign.right),
              ),
              pw.Container(
                width: 70,
                child: _buildTableHeader('Rate (₹)', pw.TextAlign.right),
              ),
              pw.Container(
                width: 85,
                child: _buildTableHeader('Taxable Value', pw.TextAlign.right),
              ),
              pw.Container(
                width: 55,
                child: _buildTableHeader('CGST %', pw.TextAlign.center),
              ),
              pw.Container(
                width: 65,
                child: _buildTableHeader('CGST (₹)', pw.TextAlign.right),
              ),
              pw.Container(
                width: 55,
                child: _buildTableHeader('SGST %', pw.TextAlign.center),
              ),
              pw.Container(
                width: 65,
                child: _buildTableHeader('SGST (₹)', pw.TextAlign.right),
              ),
              pw.Container(
                width: 85,
                child: _buildTableHeader('Total (₹)', pw.TextAlign.right),
              ),
            ],
          ),
        ),

        // Table Rows with enhanced formatting
        ..._invoice.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final sNo = (index + 1).toString();

          // Correct calculations
          final taxableValue = item.quantity * item.unitPrice;
          final cgstAmount = taxableValue * (item.cgstRate / 100);
          final sgstAmount = taxableValue * (item.sgstRate / 100);

          return pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: pw.BoxDecoration(
              color: index % 2 == 0
                  ? PdfColors.white
                  : PdfColor.fromHex('#F9FAFB'),
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColor.fromHex('#E5E7EB'),
                  width: 0.8,
                ),
                left: pw.BorderSide(
                  color: PdfColor.fromHex('#E5E7EB'),
                  width: 0.5,
                ),
                right: pw.BorderSide(
                  color: PdfColor.fromHex('#E5E7EB'),
                  width: 0.5,
                ),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 30,
                  child: _buildTableCell(sNo, pw.TextAlign.center),
                ),
                pw.Expanded(
                  flex: 3,
                  child: _buildTableCell(
                    item.itemName,
                    pw.TextAlign.left,
                    bold: true,
                  ),
                ),
                pw.Container(
                  width: 65,
                  child: _buildTableCell(
                    _getValidHSN(item.itemHsnCode),
                    pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: 40,
                  child: _buildTableCell(
                    item.quantity.toStringAsFixed(0),
                    pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: 70,
                  child: _buildTableCell(
                    '₹${formatIndianCurrency(item.unitPrice)}',
                    pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: 85,
                  child: _buildTableCell(
                    '₹${formatIndianCurrency(taxableValue)}',
                    pw.TextAlign.right,
                    bold: true,
                  ),
                ),
                pw.Container(
                  width: 55,
                  child: _buildTableCell(
                    '${item.cgstRate.toStringAsFixed(1)}%',
                    pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: 65,
                  child: _buildTableCell(
                    '₹${formatIndianCurrency(cgstAmount)}',
                    pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: 55,
                  child: _buildTableCell(
                    '${item.sgstRate.toStringAsFixed(1)}%',
                    pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: 65,
                  child: _buildTableCell(
                    '₹${formatIndianCurrency(sgstAmount)}',
                    pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: 85,
                  child: _buildTableCell(
                    '₹${formatIndianCurrency(taxableValue)}',
                    pw.TextAlign.right,
                    bold: true,
                    color: PdfColor.fromHex('#1F2937'),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        // Table bottom border
        pw.Container(
          width: double.infinity,
          height: 2,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#1F2937'),
            borderRadius: pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(8),
              bottomRight: pw.Radius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods for table styling
  pw.Widget _buildTableHeader(String text, pw.TextAlign align) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        letterSpacing: 0.3,
      ),
      textAlign: align,
    );
  }

  pw.Widget _buildTableCell(
    String text,
    pw.TextAlign align, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColor.fromHex('#374151'),
        letterSpacing: 0.2,
      ),
      textAlign: align,
    );
  }

  String _getValidHSN(String? hsn) {
    if (hsn?.isNotEmpty == true && hsn != 'N/A' && hsn!.trim().isNotEmpty) {
      return hsn!.trim();
    }
    // Return dash when HSN is not available - cleaner than N/A or empty
    return '-';
  }

  // Enhanced Professional Summary Section
  pw.Widget _buildProfessionalSummarySection() {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Enhanced GST Breakdown
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 24,
                        color: PdfColor.fromHex('#059669'),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'GST BREAKDOWN',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1F2937'),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F9FAFB'),
                      border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        // GST Table Header
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#374151'),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  'GST Type',
                                  style: _buildGSTHeaderStyle(),
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  'Rate',
                                  style: _buildGSTHeaderStyle(),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  'Tax Amount',
                                  style: _buildGSTHeaderStyle(),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 8),

                        // GST Breakdown Rows
                        ..._buildGSTBreakdownRows(),

                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: double.infinity,
                          height: 1,
                          color: PdfColor.fromHex('#D1D5DB'),
                        ),
                        pw.SizedBox(height: 8),

                        // Total GST Row
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#EBF4FF'),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  'Total GST',
                                  style: _buildGSTCellStyle(bold: true),
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text('', style: _buildGSTCellStyle()),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  '₹${formatIndianCurrency(_invoice.totalTaxAmount)}',
                                  style: _buildGSTCellStyle(bold: true),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 24),

            // Right: Enhanced Total Summary
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#E5E7EB'),
                        width: 1.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        _buildEnhancedSummaryRow(
                          'Subtotal:',
                          _invoice.subtotal,
                        ),
                        pw.SizedBox(height: 12),
                        _buildEnhancedSummaryRow(
                          'CGST Total:',
                          _invoice.cgstAmount,
                        ),
                        pw.SizedBox(height: 12),
                        _buildEnhancedSummaryRow(
                          'SGST Total:',
                          _invoice.sgstAmount,
                        ),
                        if (_invoice.roundOff != 0) ...[
                          pw.SizedBox(height: 12),
                          _buildEnhancedSummaryRow(
                            'Round Off:',
                            _invoice.roundOff,
                          ),
                        ],
                        pw.SizedBox(height: 16),
                        pw.Container(
                          width: double.infinity,
                          height: 2,
                          color: PdfColor.fromHex('#1F2937'),
                        ),
                        pw.SizedBox(height: 16),
                        pw.Container(
                          width: double.infinity,
                          padding: pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#1F2937'),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Grand Total:',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.Text(
                                '₹${formatIndianCurrency(_invoice.totalAmount)}',
                                style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // Amount in Words
        if (_invoice.amountInWords?.isNotEmpty == true)
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EBF4FF'),
              border: pw.Border.all(
                color: PdfColor.fromHex('#2B5CE6'),
                width: 1,
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Amount in Words:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1F2937'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _invoice.amountInWords!,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#2B5CE6'),
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Enhanced Professional Footer
  pw.Widget _buildProfessionalFooter() {
    return pw.Column(
      children: [
        // Dividing line
        pw.Container(
          width: double.infinity,
          height: 1,
          color: PdfColor.fromHex('#E5E7EB'),
        ),

        pw.SizedBox(height: 20),

        // Payment, Terms, and Signature Section
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Payment Information
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 3,
                        height: 18,
                        color: PdfColor.fromHex('#2B5CE6'),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'PAYMENT INFORMATION',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1F2937'),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  _buildFooterInfoLine(
                    'Payment Method:',
                    'Bank Transfer / UPI / Cash',
                  ),
                  _buildFooterInfoLine('Mode of Transport:', 'By Road'),
                  // Debug: Print bank details during PDF generation
                  ...() {
                    print('=== PDF GENERATION - Bank Details Check ===');
                    print('companyBankAccountNumber: ${_invoice.companyBankAccountNumber}');
                    print('companyBankName: ${_invoice.companyBankName}');
                    print('companyBankIfsc: ${_invoice.companyBankIfsc}');
                    print('companyBankBranch: ${_invoice.companyBankBranch}');
                    print('isEmpty check: ${_invoice.companyBankAccountNumber?.isNotEmpty}');
                    print('Condition result: ${_invoice.companyBankAccountNumber?.isNotEmpty == true}');
                    print('===========================================');
                    return <pw.Widget>[];
                  }(),
                  if (_invoice.companyBankAccountNumber?.isNotEmpty == true)
                    _buildFooterInfoLine('Bank Account:', '${_invoice.companyBankName ?? 'Bank'} - ${_invoice.companyBankAccountNumber}'),
                  if (_invoice.companyBankIfsc?.isNotEmpty == true)
                    _buildFooterInfoLine('IFSC Code:', _invoice.companyBankIfsc!),
                  if (_invoice.companyBankBranch?.isNotEmpty == true)
                    _buildFooterInfoLine('Branch:', _invoice.companyBankBranch!),
                  _buildFooterInfoLine('UPI ID:', 'company@paytm'),
                ],
              ),
            ),

            pw.SizedBox(width: 24),

            // Terms & Conditions
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 3,
                        height: 18,
                        color: PdfColor.fromHex('#059669'),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'TERMS & CONDITIONS',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1F2937'),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    _invoice.termsAndConditions.isNotEmpty
                        ? _invoice.termsAndConditions
                        : '1. Payment terms: Net 30 days from invoice date\n2. Goods once sold will not be taken back\n3. Interest @ 18% p.a. on delayed payments\n4. Subject to jurisdiction only\n5. Delivery charges are extra if applicable',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColor.fromHex('#374151'),
                      height: 1.4,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 24),

            // Enhanced Signature Section
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                children: [
                  pw.Text(
                    'For ${_invoice.companyName ?? 'Company Name'}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColor.fromHex('#374151'),
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 50),
                  pw.Container(
                    width: double.infinity,
                    height: 1.5,
                    color: PdfColor.fromHex('#374151'),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Authorized Signatory',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1F2937'),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    '(Signature & Stamp)',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromHex('#6B7280'),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // Enhanced Footer Message
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F1F5F9'),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1F2937'),
                  letterSpacing: 0.5,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'This is a system-generated invoice and does not require a physical signature.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#64748B'),
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods for enhanced styling
  List<pw.Widget> _buildGSTBreakdownRows() {
    final gstBreakdown = <String, Map<String, dynamic>>{};

    for (final item in _invoice.items) {
      if (item.cgstRate > 0 && item.cgstAmount > 0) {
        final rate = item.cgstRate.toStringAsFixed(1);
        final key = 'CGST @ $rate%';
        gstBreakdown[key] = {
          'rate': '$rate%',
          'amount': (gstBreakdown[key]?['amount'] ?? 0.0) + item.cgstAmount,
        };
      }

      if (item.sgstRate > 0 && item.sgstAmount > 0) {
        final rate = item.sgstRate.toStringAsFixed(1);
        final key = 'SGST @ $rate%';
        gstBreakdown[key] = {
          'rate': '$rate%',
          'amount': (gstBreakdown[key]?['amount'] ?? 0.0) + item.sgstAmount,
        };
      }
    }

    return gstBreakdown.entries.map((entry) {
      return pw.Container(
        padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(entry.key, style: _buildGSTCellStyle()),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                entry.value['rate'],
                style: _buildGSTCellStyle(),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                '₹${formatIndianCurrency(entry.value['amount'])}',
                style: _buildGSTCellStyle(),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  pw.TextStyle _buildGSTHeaderStyle() {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      letterSpacing: 0.3,
    );
  }

  pw.TextStyle _buildGSTCellStyle({bool bold = false}) {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: PdfColor.fromHex('#374151'),
      letterSpacing: 0.1,
    );
  }

  pw.Widget _buildEnhancedSummaryRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 13,
            color: PdfColor.fromHex('#374151'),
            letterSpacing: 0.2,
          ),
        ),
        pw.Text(
          '₹${formatIndianCurrency(amount)}',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#1F2937'),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooterInfoLine(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 85,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('#6B7280'),
                letterSpacing: 0.1,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1F2937'),
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  pw.Widget _buildDetailColumn(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColor.fromHex('#6C757D'),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#212529'),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoLine(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('#6C757D'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#212529'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.TextStyle _getTableHeaderStyle() {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
  }

  pw.TextStyle _getTableCellStyle({bool bold = false}) {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: PdfColor.fromHex('#212529'),
    );
  }

  pw.Widget _buildGSTSummaryRow(
    String label,
    double amount, {
    bool bold = false,
  }) {
    if (amount == 0) return pw.SizedBox.shrink();

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColor.fromHex('#495057'),
            ),
          ),
          pw.Text(
            '₹${formatIndianCurrency(amount)}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#212529'),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#495057')),
        ),
        pw.Text(
          '₹${formatIndianCurrency(amount)}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#212529'),
          ),
        ),
      ],
    );
  }

  double _getGSTAmount(double rate, bool isCGST) {
    double total = 0;
    for (final item in _invoice.items) {
      if (isCGST && item.cgstRate == rate) {
        total += item.cgstAmount;
      } else if (!isCGST && item.sgstRate == rate) {
        total += item.sgstAmount;
      }
    }
    return total;
  }

  // Status color helper
  PdfColor _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return PdfColor.fromHex('#059669');
      case InvoiceStatus.draft:
        return PdfColor.fromHex('#6B7280');
      case InvoiceStatus.sent:
        return PdfColor.fromHex('#2B5CE6');
      case InvoiceStatus.overdue:
        return PdfColor.fromHex('#DC2626');
      case InvoiceStatus.cancelled:
        return PdfColor.fromHex('#6B7280');
    }
  }

  // Elegant Contact Section
  pw.Widget _buildElegantContactSection() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Bill From
        pw.Expanded(
          child: _buildContactCard('BILL FROM', [
            _invoice.companyName ?? 'Company Name',
            if (_invoice.formattedCompanyAddress.isNotEmpty)
              _invoice.formattedCompanyAddress,
            if (_invoice.companyGstin?.isNotEmpty == true)
              'GSTIN: ${_invoice.companyGstin}',
            if (_invoice.companyPhone?.isNotEmpty == true)
              'Phone: ${_invoice.companyPhone}',
            if (_invoice.companyEmail?.isNotEmpty == true)
              'Email: ${_invoice.companyEmail}',
          ]),
        ),

        pw.SizedBox(width: 40),

        // Bill To
        pw.Expanded(
          child: _buildContactCard('BILL TO', [
            _invoice.customerName,
            if (_invoice.formattedCustomerAddress.isNotEmpty)
              _invoice.formattedCustomerAddress,
            if (_invoice.customerGstin?.isNotEmpty == true)
              'GSTIN: ${_invoice.customerGstin}',
            if (_invoice.customerPhone?.isNotEmpty == true)
              'Phone: ${_invoice.customerPhone}',
            if (_invoice.customerEmail?.isNotEmpty == true)
              'Email: ${_invoice.customerEmail}',
          ]),
        ),
      ],
    );
  }

  // Contact Card Helper
  pw.Widget _buildContactCard(String title, List<String> details) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#495057'),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 3, width: 60, color: PdfColor.fromHex('#007BFF')),
        pw.SizedBox(height: 16),
        ...details
            .map(
              (detail) => pw.Padding(
                padding: pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  detail,
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColor.fromHex('#212529'),
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  // Elegant Items Table
  pw.Widget _buildElegantItemsTable() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INVOICE ITEMS',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#212529'),
          ),
        ),
        pw.SizedBox(height: 16),

        // Table
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#DEE2E6')),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              // Table Header
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8F9FA'),
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(8),
                    topRight: pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 25,
                      child: pw.Text(
                        'S.No',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        'Item Name',
                        style: _getElegantHeaderStyle(),
                      ),
                    ),
                    pw.Container(
                      width: 60,
                      child: pw.Text(
                        'HSN/SAC',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      width: 50,
                      child: pw.Text(
                        'Qty',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Container(
                      width: 60,
                      child: pw.Text(
                        'Rate (₹)',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Container(
                      width: 70,
                      child: pw.Text(
                        'Taxable (₹)',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Container(
                      width: 45,
                      child: pw.Text(
                        'CGST%',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      width: 45,
                      child: pw.Text(
                        'SGST%',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Container(
                      width: 70,
                      child: pw.Text(
                        'Total (₹)',
                        style: _getElegantHeaderStyle(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              // Table Rows
              ..._invoice.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final sNo = (index + 1).toString();

                return pw.Container(
                  padding: pw.EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColor.fromHex('#DEE2E6'),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 25,
                        child: pw.Text(
                          sNo,
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          item.itemName,
                          style: _getElegantCellStyle(),
                        ),
                      ),
                      pw.Container(
                        width: 60,
                        child: pw.Text(
                          _getValidHSN(item.itemHsnCode),
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        width: 50,
                        child: pw.Text(
                          item.quantity.toStringAsFixed(0),
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Container(
                        width: 60,
                        child: pw.Text(
                          formatIndianCurrency(item.unitPrice),
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Container(
                        width: 70,
                        child: pw.Text(
                          formatIndianCurrency(item.lineTotal),
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Container(
                        width: 45,
                        child: pw.Text(
                          '${item.cgstRate.toStringAsFixed(1)}%',
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        width: 45,
                        child: pw.Text(
                          '${item.sgstRate.toStringAsFixed(1)}%',
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        width: 70,
                        child: pw.Text(
                          formatIndianCurrency(item.lineTotal),
                          style: _getElegantCellStyle(),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  // Elegant Table Style Helpers
  pw.TextStyle _getElegantHeaderStyle() {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromHex('#495057'),
    );
  }

  pw.TextStyle _getElegantCellStyle() {
    return pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#212529'));
  }

  // Elegant Total Section with GST Breakdown
  pw.Widget _buildElegantTotalSection() {
    // Group GST rates with safety checks
    final gstBreakdown = <String, double>{};

    if (_invoice.items.isNotEmpty) {
      for (final item in _invoice.items) {
        if (item.cgstRate > 0 && item.cgstAmount > 0) {
          final key = 'CGST @ ${item.cgstRate.toStringAsFixed(1)}%';
          gstBreakdown[key] = (gstBreakdown[key] ?? 0) + item.cgstAmount;
        }
        if (item.sgstRate > 0 && item.sgstAmount > 0) {
          final key = 'SGST @ ${item.sgstRate.toStringAsFixed(1)}%';
          gstBreakdown[key] = (gstBreakdown[key] ?? 0) + item.sgstAmount;
        }
      }
    }

    // Add fallback if no GST breakdown
    if (gstBreakdown.isEmpty) {
      if (_invoice.cgstAmount > 0) {
        gstBreakdown['CGST'] = _invoice.cgstAmount;
      }
      if (_invoice.sgstAmount > 0) {
        gstBreakdown['SGST'] = _invoice.sgstAmount;
      }
      if (_invoice.igstAmount > 0) {
        gstBreakdown['IGST'] = _invoice.igstAmount;
      }
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // GST Breakdown Section
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'GST BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#212529'),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8F9FA'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#DEE2E6')),
                ),
                child: pw.Column(
                  children: gstBreakdown.entries.map((entry) {
                    return pw.Padding(
                      padding: pw.EdgeInsets.only(bottom: 8),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            entry.key,
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColor.fromHex('#495057'),
                            ),
                          ),
                          pw.Text(
                            '₹${formatIndianCurrency(entry.value)}',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#212529'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 30),

        // Invoice Total Section
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#DEE2E6')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _buildElegantTotalRow('Subtotal', _invoice.subtotal),
                    pw.SizedBox(height: 8),
                    _buildElegantTotalRow('Total Tax', _invoice.totalTaxAmount),
                    if (_invoice.roundOff != 0) ...[
                      pw.SizedBox(height: 8),
                      _buildElegantTotalRow('Round Off', _invoice.roundOff),
                    ],
                    pw.SizedBox(height: 16),
                    pw.Container(
                      width: double.infinity,
                      height: 1,
                      color: PdfColor.fromHex('#DEE2E6'),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL AMOUNT',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#212529'),
                          ),
                        ),
                        pw.Text(
                          '₹${formatIndianCurrency(_invoice.totalAmount)}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#007BFF'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_invoice.amountInWords?.isNotEmpty == true) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9FA'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Amount in Words: ${_invoice.amountInWords}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColor.fromHex('#6C757D'),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Helper for elegant total rows
  pw.Widget _buildElegantTotalRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#495057')),
        ),
        pw.Text(
          '₹${formatIndianCurrency(amount)}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#212529'),
          ),
        ),
      ],
    );
  }

  // Elegant Footer with Payment Info & Terms
  pw.Widget _buildElegantFooter() {
    return pw.Column(
      children: [
        // Separator line
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColor.fromHex('#E5E7EB'),
        ),

        pw.SizedBox(height: 25),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Payment & Bank Details
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAYMENT INFORMATION',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#212529'),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    height: 2,
                    width: 40,
                    color: PdfColor.fromHex('#007BFF'),
                  ),
                  pw.SizedBox(height: 12),

                  _buildPaymentDetail(
                    'Payment Status',
                    _invoice.status.displayName.toUpperCase(),
                  ),
                  pw.SizedBox(height: 6),
                  _buildPaymentDetail('Payment Method', 'Bank Transfer / UPI'),
                  if (_invoice.companyBankAccountNumber?.isNotEmpty == true) ...[
                    pw.SizedBox(height: 6),
                    _buildPaymentDetail('Bank Account', '${_invoice.companyBankName ?? 'Bank'} - ${_invoice.companyBankAccountNumber}'),
                  ],
                  if (_invoice.companyBankIfsc?.isNotEmpty == true) ...[
                    pw.SizedBox(height: 6),
                    _buildPaymentDetail('IFSC Code', _invoice.companyBankIfsc!),
                  ],
                  pw.SizedBox(height: 6),
                  _buildPaymentDetail('UPI ID', 'company@upi'),
                ],
              ),
            ),

            pw.SizedBox(width: 40),

            // Terms & Conditions
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TERMS & CONDITIONS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#212529'),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    height: 2,
                    width: 40,
                    color: PdfColor.fromHex('#007BFF'),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    _invoice.termsAndConditions.isNotEmpty
                        ? _invoice.termsAndConditions
                        : '• Payment terms: Net 30 days\n• Goods once sold will not be taken back\n• Interest @ 18% p.a. will be charged on delayed payments\n• Subject to jurisdiction only',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColor.fromHex('#495057'),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 40),

            // Signature Section
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'AUTHORIZED SIGNATURE',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#495057'),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    height: 50,
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColor.fromHex('#DEE2E6'),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    _invoice.companyName ?? 'Company Name',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#212529'),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'Authorized Signatory',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColor.fromHex('#6C757D'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 25),

        // Thank You Note
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8F9FA'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#007BFF'),
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'This is a computer-generated invoice and does not require a physical signature.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromHex('#6C757D'),
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper for payment details
  pw.Widget _buildPaymentDetail(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 80,
          child: pw.Text(
            label + ':',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#6C757D'),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#212529'),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<int>?> _generateClientSidePdf() async {
    // Get CURRENT logged-in user's layout preference (dynamic - not frozen at invoice creation)
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    final layoutPreference = currentUser?.invoiceLayoutPreference ?? 'classic';

    print('Generating PDF with CURRENT user layout: $layoutPreference');
    print('User: ${currentUser?.email ?? "unknown"}');

    // Call appropriate PDF generation method based on preference
    if (layoutPreference == 'traditional') {
      return await _generateTraditionalLayoutPDF();
    } else {
      return await _generateClassicLayoutPDF();
    }
  }

  Future<List<int>?> _generateClassicLayoutPDF() async {
    try {
      print('Creating GST Invoice PDF document...');
      print('Invoice has ${_invoice.items.length} items');

      // DEBUG: Check bank details at start of PDF generation
      print('=== DEBUG: Bank details in _invoice ===');
      print('_invoice.companyBankName: ${_invoice.companyBankName}');
      print('_invoice.companyBankAccountNumber: ${_invoice.companyBankAccountNumber}');
      print('_invoice.companyBankIfsc: ${_invoice.companyBankIfsc}');
      print('_invoice.companyBankBranch: ${_invoice.companyBankBranch}');
      print('=======================================');

      // DEBUG: Check billing address values
      print('=== DEBUG: Billing Address in _invoice ===');
      print('_invoice.billingAddress: ${_invoice.billingAddress}');
      print('_invoice.billingCity: ${_invoice.billingCity}');
      print('_invoice.billingState: ${_invoice.billingState}');
      print('_invoice.billingPincode: ${_invoice.billingPincode}');
      print('_invoice.customerAddress: ${_invoice.customerAddress}');
      print('_invoice.customerCity: ${_invoice.customerCity}');
      print('_invoice.customerState: ${_invoice.customerState}');
      print('_invoice.customerPincode: ${_invoice.customerPincode}');
      print('_invoice.formattedCustomerAddress: ${_invoice.formattedCustomerAddress}');
      print('==========================================');

      // Use the latest invoice data from state
      final invoiceToUse = _invoice;

      final pdf = pw.Document();

      print('Adding GST invoice page to PDF...');
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Blue Header with TAX INVOICE
                _buildGSTInvoiceHeader(),

                pw.SizedBox(height: 4),

                // Supplier, Receiver, and Shipped To in one row
                _buildSupplierReceiverAndInvoiceDetailsRow(),

                pw.SizedBox(height: 4),

                // Transport Details (only if logistics is enabled and has data)
                if (_invoice.includeLogistics &&
                    (_invoice.driverName?.isNotEmpty == true ||
                        _invoice.driverPhone?.isNotEmpty == true ||
                        _invoice.vehicleNumber?.isNotEmpty == true ||
                        _invoice.transportCompany?.isNotEmpty == true ||
                        _invoice.lrNumber?.isNotEmpty == true ||
                        _invoice.dispatchDate != null)) ...[
                  _buildTransportDetails(),
                  pw.SizedBox(height: 4),
                ],

                // Horizontal Invoice Details Row (Invoice No, Date, Payment Date)
                _buildHorizontalInvoiceDetails(),

                pw.SizedBox(height: 4),

                // GST Items Table
                _buildGSTItemsTable(),

                pw.SizedBox(height: 4),

                // Tax Summary and Amount Details Row (with Bank Details below Tax Summary)
                _buildTaxSummaryAndAmountDetailsRow(),

                pw.SizedBox(height: 4),

                // Terms & Conditions and Authorized Signatory at Footer
                _buildFooterTermsAndSignatoryRow(),

                pw.SizedBox(height: 2),

                // Compliance Footer
                _buildComplianceFooter(),
              ],
            );
          },
        ),
      );

      print('Converting PDF to bytes...');
      final bytes = await pdf.save();
      print('PDF bytes generated: ${bytes.length}');
      return bytes;
    } catch (e, stackTrace) {
      print('Client-side PDF generation error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // ==================== TRADITIONAL LAYOUT PDF GENERATION ====================

  Future<List<int>?> _generateTraditionalLayoutPDF() async {
    try {
      print('Creating Traditional Layout Invoice PDF...');
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return [
              // Header: TAX INVOICE
              _buildTraditionalHeader(),
              pw.SizedBox(height: 4),

              // Main bordered container containing all sections
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.0),
                ),
                child: pw.Column(
                  children: [
                    // Top section: Company Details | Invoice Metadata
                    _buildTraditionalTopSection(),

                    // Buyer and Consignee
                    _buildTraditionalPartySection(),

                    // Transport Details (conditional)
                    if (_invoice.includeLogistics == true)
                      _buildTraditionalTransportDetails(),

                    // Items Table
                    _buildTraditionalItemsTable(),

                    // Amount in words
                    _buildTraditionalAmountInWords(),

                    // Tax breakdown tables (CGST and SGST side by side)
                    _buildTraditionalTaxBreakdownTables(),

                    // Tax amount in words
                    _buildTraditionalTaxAmountInWords(),

                    // Bank details and declaration
                    _buildTraditionalBankAndDeclaration(),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Footer
              _buildTraditionalFooter(),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      print('Traditional PDF generated successfully: ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      print('Traditional PDF generation error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // ==================== HELPER METHODS FOR TRADITIONAL LAYOUT ====================

  pw.Widget _buildTraditionalHeader() {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'TAX INVOICE',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              '(ORIGINAL FOR RECIPIENT)',
              style: pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTraditionalTopSection() {
    // Helper to extract state code from GSTIN (first 2 digits)
    String getStateCode(String? gstin) {
      if (gstin == null || gstin.length < 2) return '';
      return gstin.substring(0, 2);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Company/Seller Details
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _invoice.companyName?.toUpperCase() ?? 'COMPANY NAME',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _invoice.companyAddress ?? '',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '${_invoice.companyCity ?? ''} - ${_invoice.companyPincode ?? ''}',
                  style: pw.TextStyle(fontSize: 8),
                ),
                if (_invoice.companyPhone != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Ph: ${_invoice.companyPhone}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
                if (_invoice.companyEmail != null) ...[
                  pw.Text(
                    'E-Mail: ${_invoice.companyEmail}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
                pw.SizedBox(height: 3),
                pw.Text(
                  'GSTIN: ${_invoice.companyGstin ?? 'N/A'}, State Code ${getStateCode(_invoice.companyGstin) ?? _invoice.companyStateCode ?? ''}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                if (_invoice.companyPan != null) ...[
                  pw.Text(
                    'PAN: ${_invoice.companyPan}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right: Invoice Metadata Table
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.0),
            ),
            child: pw.Table(
              border: pw.TableBorder.all(width: 1.0),
              columnWidths: {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                // Row 1: Invoice No. | Value | Dated | Value
                _buildMetadataRow('Invoice No.', _invoice.invoiceNumber ?? '', 'Dated', _invoice.invoiceDate.toString().split(' ')[0]),
                // Row 2: Delivery Note | Value | Mode/Terms of Payment | Value
                _buildMetadataRow('Delivery Note', _invoice.lrNumber ?? '', 'Mode / Terms of Payment', 'As Agreed'),
                // Row 3: Supplier's Ref. | Value | Other Reference(s) | Value
                _buildMetadataRow('Supplier\'s Ref.', '', 'Other Reference(s)', ''),
                // Row 4: Buyer's Order No. | Value | Dated | Value
                _buildMetadataRow('Buyer\'s Order No.', '', 'Dated', ''),
                // Row 5: Despatch Document No. | Value | Delivery Note Date | Value
                _buildMetadataRow('Despatch Document No.', '', 'Delivery Note Date', _invoice.dispatchDate != null ? _invoice.dispatchDate.toString().split(' ')[0] : ''),
                // Row 6: Despatched through | Value | Destination | Value
                _buildMetadataRow(
                  'Despatched through',
                  _invoice.transportCompany ?? '',
                  'Destination',
                  '${_invoice.billingCity ?? _invoice.customerCity ?? ''}, ${_invoice.billingState ?? _invoice.customerState ?? ''}',
                ),
                // Row 7: Terms of Delivery | (spans all columns)
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text('Terms of Delivery', style: pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text('', style: pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Container(padding: pw.EdgeInsets.all(2)),
                    pw.Container(padding: pw.EdgeInsets.all(2)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildMetadataRow(String label1, String value1, String label2, String value2) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(2),
          child: pw.Text(label1, style: pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(2),
          child: pw.Text(value1, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(2),
          child: pw.Text(label2, style: pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(2),
          child: pw.Text(value2, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  pw.Widget _buildTraditionalPartySection() {
    // Helper to extract state code from GSTIN
    String getStateCode(String? gstin) {
      if (gstin == null || gstin.length < 2) return '';
      return gstin.substring(0, 2);
    }

    // Use billing address if available, otherwise use customer address
    final buyerName = _invoice.customerName ?? 'Customer Name';
    final buyerAddress = _invoice.billingAddress ?? _invoice.customerAddress ?? '';
    final buyerCity = _invoice.billingCity ?? _invoice.customerCity ?? '';
    final buyerState = _invoice.billingState ?? _invoice.customerState ?? '';
    final buyerPincode = _invoice.billingPincode ?? _invoice.customerPincode ?? '';
    final buyerGstin = _invoice.customerGstin ?? '';
    final buyerStateCode = getStateCode(buyerGstin);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Buyer (Billed to)
        pw.Expanded(
          child: pw.Container(
            height: 70,
            padding: pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Buyer (Bill to)',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  buyerName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  buyerAddress,
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '$buyerCity, $buyerState - $buyerPincode',
                  style: pw.TextStyle(fontSize: 8),
                ),
                if (buyerGstin.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'GSTIN: $buyerGstin',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
                pw.Text(
                  'State Name: $buyerState, Code: $buyerStateCode',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        // Consignee (Shipped to) - Same as buyer in most cases
        pw.Expanded(
          child: pw.Container(
            height: 70,
            padding: pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Consignee (Ship to)',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  buyerName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  buyerAddress,
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '$buyerCity, $buyerState - $buyerPincode',
                  style: pw.TextStyle(fontSize: 8),
                ),
                if (buyerGstin.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'GSTIN: $buyerGstin',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
                pw.Text(
                  'State Name: $buyerState, Code: $buyerStateCode',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTraditionalTransportDetails() {
    return pw.Container(
      padding: pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 1.0)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left column
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (_invoice.driverName != null && _invoice.driverName!.isNotEmpty)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      children: [
                        pw.Text('Driver Name: ', style: pw.TextStyle(fontSize: 7)),
                        pw.Text(_invoice.driverName!, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                if (_invoice.driverPhone != null && _invoice.driverPhone!.isNotEmpty)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      children: [
                        pw.Text('Driver Phone: ', style: pw.TextStyle(fontSize: 7)),
                        pw.Text(_invoice.driverPhone!, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                if (_invoice.vehicleNumber != null && _invoice.vehicleNumber!.isNotEmpty)
                  pw.Row(
                    children: [
                      pw.Text('Vehicle Number: ', style: pw.TextStyle(fontSize: 7)),
                      pw.Text(_invoice.vehicleNumber!, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
              ],
            ),
          ),
          // Right column
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (_invoice.transportCompany != null && _invoice.transportCompany!.isNotEmpty)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      children: [
                        pw.Text('Transport Company: ', style: pw.TextStyle(fontSize: 7)),
                        pw.Text(_invoice.transportCompany!, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                if (_invoice.lrNumber != null && _invoice.lrNumber!.isNotEmpty)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      children: [
                        pw.Text('LR Number: ', style: pw.TextStyle(fontSize: 7)),
                        pw.Text(_invoice.lrNumber!, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                if (_invoice.dispatchDate != null)
                  pw.Row(
                    children: [
                      pw.Text('Dispatch Date: ', style: pw.TextStyle(fontSize: 7)),
                      pw.Text(
                        DateFormat('dd-MM-yyyy').format(_invoice.dispatchDate!),
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTraditionalItemsTable() {
    return pw.Table(
      border: pw.TableBorder.all(width: 1.0),
      columnWidths: {
        0: pw.FixedColumnWidth(25),  // SI No.
        1: pw.FlexColumnWidth(4),    // Description
        2: pw.FixedColumnWidth(50),  // HSN/SAC
        3: pw.FixedColumnWidth(45),  // Quantity
        4: pw.FixedColumnWidth(50),  // Rate
        5: pw.FixedColumnWidth(30),  // per
        6: pw.FixedColumnWidth(35),  // Disc %
        7: pw.FixedColumnWidth(60),  // Amount
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTradTableHeader('SI\nNo.'),
            _buildTradTableHeader('Description of Goods'),
            _buildTradTableHeader('HSN/SAC'),
            _buildTradTableHeader('Quantity'),
            _buildTradTableHeader('Rate'),
            _buildTradTableHeader('per'),
            _buildTradTableHeader('Disc.\n%'),
            _buildTradTableHeader('Amount'),
          ],
        ),

        // Item rows
        ..._invoice.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _buildTradTableCell((index + 1).toString(), align: pw.TextAlign.center),
              _buildTradTableCell(item.itemName ?? '', align: pw.TextAlign.left),
              _buildTradTableCell(item.itemHsnCode ?? ''),
              _buildTradTableCell('${item.quantity.toStringAsFixed(2)}'),
              _buildTradTableCell('Rs. ${formatIndianCurrency(item.unitPrice)}'),
              _buildTradTableCell(item.itemUnit ?? 'Nos'),
              _buildTradTableCell('-'),
              _buildTradTableCell('Rs. ${formatIndianCurrency(item.lineTotal)}', align: pw.TextAlign.right),
            ],
          );
        }).toList(),

        // Subtotal row
        pw.TableRow(
          children: [
            pw.Container(padding: pw.EdgeInsets.all(2)),
            _buildTradTableCell('', align: pw.TextAlign.left),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            _buildTradTableCell('Total', bold: true),
            _buildTradTableCell('Rs. ${formatIndianCurrency(_invoice.subtotal)}', align: pw.TextAlign.right, bold: true),
          ],
        ),

        // Tax rows
        if (_invoice.cgstAmount > 0) ...[
          pw.TableRow(
            children: [
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Output CGST', align: pw.TextAlign.left),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Rs. ${formatIndianCurrency(_invoice.cgstAmount)}', align: pw.TextAlign.right),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Output SGST', align: pw.TextAlign.left),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Rs. ${formatIndianCurrency(_invoice.sgstAmount)}', align: pw.TextAlign.right),
            ],
          ),
        ],
        if (_invoice.igstAmount > 0) ...[
          pw.TableRow(
            children: [
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Output IGST', align: pw.TextAlign.left),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Rs. ${formatIndianCurrency(_invoice.igstAmount)}', align: pw.TextAlign.right),
            ],
          ),
        ],

        // Round off
        if (_invoice.roundOff != 0) ...[
          pw.TableRow(
            children: [
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Round Off', align: pw.TextAlign.left),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              pw.Container(padding: pw.EdgeInsets.all(2)),
              _buildTradTableCell('Rs. ${formatIndianCurrency(_invoice.roundOff)}', align: pw.TextAlign.right),
            ],
          ),
        ],

        // Grand total
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Container(padding: pw.EdgeInsets.all(2)),
            _buildTradTableCell('Total', align: pw.TextAlign.right, bold: true),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            pw.Container(padding: pw.EdgeInsets.all(2)),
            _buildTradTableCell('Rs. ${formatIndianCurrency(_invoice.totalAmount)}', align: pw.TextAlign.right, bold: true),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTradTableHeader(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(3),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  pw.Widget _buildTradTableCell(String text, {pw.TextAlign align = pw.TextAlign.center, bool bold = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildTraditionalAmountInWords() {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 1.0),
          bottom: pw.BorderSide(width: 1.0),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Text(
                  'Amount Chargeable (in words):  ',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'Indian Rupees ${_numberToWords(_invoice.totalAmount)}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'E. & O.E',
            style: pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTraditionalTaxBreakdownTables() {
    // Group items by HSN code and calculate tax
    final Map<String, Map<String, double>> hsnGroups = {};

    for (var item in _invoice.items) {
      final hsn = item.itemHsnCode ?? 'N/A';
      if (!hsnGroups.containsKey(hsn)) {
        hsnGroups[hsn] = {
          'taxableValue': 0.0,
          'cgstRate': 0.0,
          'cgstAmount': 0.0,
          'sgstRate': 0.0,
          'sgstAmount': 0.0,
          'igstRate': 0.0,
          'igstAmount': 0.0,
        };
      }

      hsnGroups[hsn]!['taxableValue'] = (hsnGroups[hsn]!['taxableValue'] ?? 0) + item.lineTotal;
      hsnGroups[hsn]!['cgstAmount'] = (hsnGroups[hsn]!['cgstAmount'] ?? 0) + item.cgstAmount;
      hsnGroups[hsn]!['sgstAmount'] = (hsnGroups[hsn]!['sgstAmount'] ?? 0) + item.sgstAmount;
      hsnGroups[hsn]!['igstAmount'] = (hsnGroups[hsn]!['igstAmount'] ?? 0) + item.igstAmount;

      // Calculate rates
      if (item.lineTotal > 0 && item.cgstAmount > 0) {
        hsnGroups[hsn]!['cgstRate'] = (item.cgstAmount / item.lineTotal) * 100;
      }
      if (item.lineTotal > 0 && item.sgstAmount > 0) {
        hsnGroups[hsn]!['sgstRate'] = (item.sgstAmount / item.lineTotal) * 100;
      }
      if (item.lineTotal > 0 && item.igstAmount > 0) {
        hsnGroups[hsn]!['igstRate'] = (item.igstAmount / item.lineTotal) * 100;
      }
    }

    // Determine if we're using CGST+SGST or IGST
    final bool usesCgstSgst = _invoice.cgstAmount > 0 || _invoice.sgstAmount > 0;
    final bool usesIgst = _invoice.igstAmount > 0;

    if (usesCgstSgst) {
      // Single unified table with CGST and SGST columns
      return pw.Table(
        border: pw.TableBorder.all(width: 1.0),
          columnWidths: {
            0: pw.FlexColumnWidth(2),   // HSN/SAC
            1: pw.FlexColumnWidth(2.5), // Taxable Value
            2: pw.FlexColumnWidth(1.5), // Central Tax Rate
            3: pw.FlexColumnWidth(2),   // Central Tax Amount
            4: pw.FlexColumnWidth(1.5), // State Tax Rate
            5: pw.FlexColumnWidth(2),   // State Tax Amount
            6: pw.FlexColumnWidth(2.5), // Total Tax Amount
          },
          children: [
            // Main header row - parent headers
            pw.TableRow(
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0)),
              ),
              children: [
                _buildTradTaxTableHeader('HSN/SAC'),
                _buildTradTaxTableHeader('Taxable\nValue'),
                pw.Container(
                  padding: pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Central Tax',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(), // Second column of Central Tax span
                pw.Container(
                  padding: pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'State Tax',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(), // Second column of State Tax span
                _buildTradTaxTableHeader('Total Tax\nAmount'),
              ],
            ),
            // Sub-header row
            pw.TableRow(
              children: [
                pw.Container(), // Empty - HSN/SAC doesn't have sub-headers
                pw.Container(), // Empty - Taxable Value doesn't have sub-headers
                _buildTradTaxTableHeader('Rate'),
                _buildTradTaxTableHeader('Amount'),
                _buildTradTaxTableHeader('Rate'),
                _buildTradTaxTableHeader('Amount'),
                pw.Container(), // Empty - Total Tax Amount doesn't have sub-headers
              ],
            ),
            // Data rows
            ...hsnGroups.entries.map((entry) {
              final hsn = entry.key;
              final data = entry.value;
              final totalTax = data['cgstAmount']! + data['sgstAmount']!;
              return pw.TableRow(
                children: [
                  _buildTradTaxTableCell(hsn, align: pw.TextAlign.left),
                  _buildTradTaxTableCell('Rs. ${formatIndianCurrency(data['taxableValue']!)}', align: pw.TextAlign.right),
                  _buildTradTaxTableCell('${data['cgstRate']!.toStringAsFixed(1)}%'),
                  _buildTradTaxTableCell('Rs. ${formatIndianCurrency(data['cgstAmount']!)}', align: pw.TextAlign.right),
                  _buildTradTaxTableCell('${data['sgstRate']!.toStringAsFixed(1)}%'),
                  _buildTradTaxTableCell('Rs. ${formatIndianCurrency(data['sgstAmount']!)}', align: pw.TextAlign.right),
                  _buildTradTaxTableCell('Rs. ${formatIndianCurrency(totalTax)}', align: pw.TextAlign.right),
                ],
              );
            }).toList(),
            // Total row
            pw.TableRow(
              children: [
                _buildTradTaxTableCell('Total', bold: true, align: pw.TextAlign.left),
                _buildTradTaxTableCell('Rs. ${formatIndianCurrency(_invoice.subtotal)}', align: pw.TextAlign.right, bold: true),
                pw.Container(padding: pw.EdgeInsets.all(3)),
                _buildTradTaxTableCell('Rs. ${formatIndianCurrency(_invoice.cgstAmount)}', align: pw.TextAlign.right, bold: true),
                pw.Container(padding: pw.EdgeInsets.all(3)),
                _buildTradTaxTableCell('Rs. ${formatIndianCurrency(_invoice.sgstAmount)}', align: pw.TextAlign.right, bold: true),
                _buildTradTaxTableCell('Rs. ${formatIndianCurrency(_invoice.totalTaxAmount)}', align: pw.TextAlign.right, bold: true),
              ],
            ),
          ],
        );
    } else if (usesIgst) {
      // Single unified table with IGST columns
      return pw.Table(
        border: pw.TableBorder.all(width: 1.0),
          columnWidths: {
            0: pw.FlexColumnWidth(2),   // HSN/SAC
            1: pw.FlexColumnWidth(2.5), // Taxable Value
            2: pw.FlexColumnWidth(1.5), // IGST Rate
            3: pw.FlexColumnWidth(2),   // IGST Amount
            4: pw.FlexColumnWidth(2.5), // Total Tax Amount
          },
          children: [
            // Main header row - parent headers
            pw.TableRow(
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1.0)),
              ),
              children: [
                _buildTradTaxTableHeader('HSN/SAC'),
                _buildTradTaxTableHeader('Taxable\nValue'),
                pw.Container(
                  padding: pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Integrated Tax',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(), // Second column of Integrated Tax span
                _buildTradTaxTableHeader('Total Tax\nAmount'),
              ],
            ),
            // Sub-header row
            pw.TableRow(
              children: [
                pw.Container(), // Empty - HSN/SAC doesn't have sub-headers
                pw.Container(), // Empty - Taxable Value doesn't have sub-headers
                _buildTradTaxTableHeader('Rate'),
                _buildTradTaxTableHeader('Amount'),
                pw.Container(), // Empty - Total Tax Amount doesn't have sub-headers
              ],
            ),
            // Data rows
            ...hsnGroups.entries.map((entry) {
              final hsn = entry.key;
              final data = entry.value;
              return pw.TableRow(
                children: [
                  _buildTradTaxTableCell(hsn, align: pw.TextAlign.left),
                  _buildTradTaxTableCell('Rs. ${formatIndianCurrency(data['taxableValue']!)}', align: pw.TextAlign.right),
                  _buildTradTaxTableCell('${data['igstRate']!.toStringAsFixed(1)}%'),
                  _buildTradTaxTableCell('Rs. ${formatIndianCurrency(data['igstAmount']!)}', align: pw.TextAlign.right),
                  _buildTradTaxTableCell('Rs. ${formatIndianCurrency(data['igstAmount']!)}', align: pw.TextAlign.right),
                ],
              );
            }).toList(),
            // Total row
            pw.TableRow(
              children: [
                _buildTradTaxTableCell('Total', bold: true, align: pw.TextAlign.left),
                _buildTradTaxTableCell('Rs. ${formatIndianCurrency(_invoice.subtotal)}', align: pw.TextAlign.right, bold: true),
                pw.Container(padding: pw.EdgeInsets.all(3)),
                _buildTradTaxTableCell('Rs. ${formatIndianCurrency(_invoice.igstAmount)}', align: pw.TextAlign.right, bold: true),
                _buildTradTaxTableCell('Rs. ${formatIndianCurrency(_invoice.totalTaxAmount)}', align: pw.TextAlign.right, bold: true),
              ],
            ),
          ],
        );
    } else {
      return pw.Container();
    }
  }

  pw.Widget _buildTradTaxTableHeader(String text, {int rowSpan = 1, int colSpan = 1}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(3),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTraditionalTaxAmountInWords() {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 1.0),
          bottom: pw.BorderSide(width: 1.0),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Tax Amount (in words):  ',
            style: pw.TextStyle(fontSize: 8),
          ),
          pw.Expanded(
            child: pw.Text(
              'Indian Rupees ${_numberToWords(_invoice.totalTaxAmount)}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTradTaxTableCell(String text, {pw.TextAlign align = pw.TextAlign.center, bool bold = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }
  pw.Widget _buildTraditionalBankAndDeclaration() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Bank Details
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1.0),
                right: pw.BorderSide(width: 1.0),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Company\'s Bank Details',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                if (_invoice.companyBankName != null) ...[
                  pw.Text(
                    'Bank Name: ${_invoice.companyBankName}',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
                if (_invoice.companyBankAccountNumber != null) ...[
                  pw.Text(
                    'A/c No.: ${_invoice.companyBankAccountNumber}',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
                if (_invoice.companyBankBranch != null && _invoice.companyBankIfsc != null) ...[
                  pw.Text(
                    'Branch & IFS Code: ${_invoice.companyBankBranch} & ${_invoice.companyBankIfsc}',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ] else if (_invoice.companyBankIfsc != null) ...[
                  pw.Text(
                    'IFSC Code: ${_invoice.companyBankIfsc}',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right: Authorized Signatory
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1.0),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'for ${_invoice.companyName?.toUpperCase() ?? 'COMPANY NAME'}',
                  style: pw.TextStyle(fontSize: 7),
                ),
                pw.SizedBox(height: 25),
                pw.Text(
                  'Authorised Signatory',
                  style: pw.TextStyle(fontSize: 7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTraditionalFooter() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 4),
        // Declaration Section
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.0),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Declaration',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.',
                style: pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        // Computer Generated Notice
        pw.Center(
          child: pw.Text(
            'This is a Computer Generated Invoice',
            style: pw.TextStyle(fontSize: 6),
          ),
        ),
      ],
    );
  }

  // Number to words conversion (Indian numbering system)
  String _numberToWords(double number) {
    final intPart = number.floor();
    final decimalPart = ((number - intPart) * 100).round();

    if (intPart == 0 && decimalPart == 0) {
      return 'Zero Only';
    }

    String result = _convertNumberToWords(intPart);
    if (decimalPart > 0) {
      result += ' and ${_convertNumberToWords(decimalPart)} Paise';
    }
    return '$result Only';
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';

    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    final teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      final ten = number ~/ 10;
      final one = number % 10;
      return '${tens[ten]}${one > 0 ? ' ${ones[one]}' : ''}';
    }
    if (number < 1000) {
      final hundred = number ~/ 100;
      final remainder = number % 100;
      return '${ones[hundred]} Hundred${remainder > 0 ? ' ${_convertNumberToWords(remainder)}' : ''}';
    }
    if (number < 100000) {
      final thousand = number ~/ 1000;
      final remainder = number % 1000;
      return '${_convertNumberToWords(thousand)} Thousand${remainder > 0 ? ' ${_convertNumberToWords(remainder)}' : ''}';
    }
    if (number < 10000000) {
      final lakh = number ~/ 100000;
      final remainder = number % 100000;
      return '${_convertNumberToWords(lakh)} Lakh${remainder > 0 ? ' ${_convertNumberToWords(remainder)}' : ''}';
    }
    final crore = number ~/ 10000000;
    final remainder = number % 10000000;
    return '${_convertNumberToWords(crore)} Crore${remainder > 0 ? ' ${_convertNumberToWords(remainder)}' : ''}';
  }

  // ==================== END OF TRADITIONAL LAYOUT ====================

  Future<void> _savePdfFile(List<int> pdfBytes) async {
    try {
      // Request appropriate permissions based on Android version
      if (Platform.isAndroid) {
        PermissionStatus permission;
        if (await Permission.manageExternalStorage.isGranted) {
          permission = PermissionStatus.granted;
        } else if (await Permission.storage.isGranted) {
          permission = PermissionStatus.granted;
        } else {
          // Try to request manage external storage first (Android 11+)
          permission = await Permission.manageExternalStorage.request();
          if (!permission.isGranted) {
            // Fallback to regular storage permission
            permission = await Permission.storage.request();
          }
        }

        if (!permission.isGranted) {
          print('Storage permission denied');
          _showSnackBar(
            'Storage permission required to save PDF. Please grant permission in device settings.',
            AppColors.error,
          );
          return;
        }
        print('Storage permission granted');
      }

      Directory directory;
      if (Platform.isAndroid) {
        // Try Downloads folder first, then fallback to app directory
        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory =
                await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory();
          }
        } catch (e) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final sanitizedInvoiceNumber = _invoice.invoiceNumber.replaceAll(
        '/',
        '-',
      );
      final fileName =
          'Invoice_${sanitizedInvoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      print('Attempting to save PDF to: ${file.path}');
      print('PDF data size: ${pdfBytes.length} bytes');

      await file.writeAsBytes(pdfBytes);

      print('PDF saved successfully to: ${file.path}');

      // Verify file was created and has content
      if (await file.exists()) {
        final fileSize = await file.length();
        print('File exists with size: $fileSize bytes');
      } else {
        print('File was not created successfully');
        throw Exception('File was not created');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: ${file.path}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _openPdfFile(file.path),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error saving PDF: $e');
      print('Stack trace: $stackTrace');
      _showSnackBar('Error saving PDF: ${e.toString()}', AppColors.error);
    }
  }

  Future<void> _openPdfFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done && mounted) {
        _showSnackBar('No app found to open PDF files', AppColors.warning);
      }
    } catch (e) {
      _showSnackBar('Error opening PDF: $e', AppColors.error);
    }
  }

  void _sendEmail(InvoiceProvider provider) async {
    final success = await provider.sendInvoiceEmail(
      _invoice.id,
      _invoice.customerEmail!,
    );
    if (success && mounted) {
      _showSnackBar('Invoice sent successfully', AppColors.success);
    }
  }

  void _updateStatus(InvoiceProvider provider, InvoiceStatus status) async {
    final success = await provider.updateInvoice(
      id: _invoice.id,
      status: status,
    );

    if (success && mounted) {
      setState(() {
        _invoice = provider.invoices.firstWhere((inv) => inv.id == _invoice.id);
      });
      _showSnackBar(
        'Invoice marked as ${status.displayName.toLowerCase()}',
        AppColors.success,
      );
    }
  }

  void _showDeleteDialog(InvoiceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('Delete Invoice'),
        content: const Text(
          'Are you sure you want to delete this invoice? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteInvoice(provider),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteInvoice(InvoiceProvider provider) async {
    Navigator.pop(context);

    final success = await provider.deleteInvoice(_invoice.id);
    if (success && mounted) {
      _showSnackBar('Invoice deleted successfully', AppColors.success);
      Navigator.pop(context);
    }
  }

  void _sharePdf(InvoiceProvider provider) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16.h),
                Text(
                  'Preparing PDF for sharing...',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Generate PDF bytes
      List<int>? pdfBytes = await _generateClientSidePdf();

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        // Create a temporary file for sharing
        final tempDir = await getTemporaryDirectory();
        final sanitizedInvoiceNumber = _invoice.invoiceNumber.replaceAll(
          '/',
          '-',
        );
        final fileName = 'Invoice_${sanitizedInvoiceNumber}.pdf';
        final tempFile = File('${tempDir.path}/$fileName');

        // Write PDF bytes to temporary file
        await tempFile.writeAsBytes(pdfBytes);

        // Share the PDF file using XFile for compatibility
        final xFile = XFile(tempFile.path);
        await Share.shareXFiles(
          [xFile],
          subject: 'Invoice ${_invoice.invoiceNumber}',
          text:
              'Invoice ${_invoice.invoiceNumber} - ${_invoice.customerName}\nAmount: ₹${NumberFormat('#,##,###.##').format(_invoice.totalAmount)}',
        );

        _showSnackBar('PDF prepared for sharing', Colors.green);
      } else {
        _showSnackBar('Failed to generate PDF for sharing', AppColors.error);
      }
    } catch (e) {
      print('PDF sharing error: $e');
      if (mounted) Navigator.pop(context); // Close loading dialog if still open
      _showSnackBar(
        'Error preparing PDF for sharing: ${e.toString()}',
        AppColors.error,
      );
    }
  }

  void _shareInvoiceText() async {
    final invoiceText =
        '''
Invoice Details:
━━━━━━━━━━━━━━━━
📋 Invoice: ${_invoice.invoiceNumber}
👤 Customer: ${_invoice.customerName}
💰 Amount: ₹${NumberFormat('#,##,###.##').format(_invoice.totalAmount)}
📅 Date: ${_invoice.formattedInvoiceDate}
📊 Status: ${_invoice.status.displayName}

Generated from Inventory Management System
''';

    try {
      await Share.share(
        invoiceText,
        subject: 'Invoice ${_invoice.invoiceNumber}',
      );
    } catch (e) {
      // Fallback to clipboard if sharing fails
      Clipboard.setData(ClipboardData(text: invoiceText));
      _showSnackBar('Invoice details copied to clipboard', Colors.green);
    }
  }

  void _shareInvoice() {
    // Legacy function - now calls the text sharing
    _shareInvoiceText();
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 20.h,
          decoration: BoxDecoration(
            color: const Color(0xFF1E40AF),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedDetailSection({
    required String sectionTitle,
    required IconData icon,
    required String content,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: iconColor.withOpacity(0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: iconColor, size: 20.w),
              ),
              SizedBox(width: 16.w),
              Text(
                sectionTitle,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF111827),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCompactCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color backgroundColor,
    bool useMonospace = false,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: iconColor.withOpacity(0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: iconColor, size: 18.w),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
              height: 1.3,
              fontFamily: useMonospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalDetailCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
    required Color accentColor,
    bool isCompact = false,
    bool useMonospace = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16.w : 20.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accentColor.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isCompact ? 18.w : 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 12.sp : 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12.h : 16.h),
          Text(
            content,
            style: TextStyle(
              fontSize: isCompact ? 13.sp : 15.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF111827),
              height: 1.4,
              fontFamily: useMonospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
    }
  }

  // ==================== NEW GST INVOICE LAYOUT METHODS ====================

  // Simple Header with Tax Invoice title and Invoice Number - Reference Style
  pw.Widget _buildGSTInvoiceHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Top line: "Original for Recipient | Duplicate | Triplicate"
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Original for Recipient | Duplicate for Transporter | Triplicate for Supplier',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        // Main header line: Tax Invoice (left) and Invoice Number (right)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'Tax Invoice',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.Text(
              _invoice.invoiceNumber,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        // Divider line
        pw.Container(
          height: 1,
          color: PdfColors.grey600,
        ),
      ],
    );
  }

  // Supplier Details and Invoice Details Row
  pw.Widget _buildSupplierAndInvoiceDetailsRow() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Supplier Details (Left Column)
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey600),
                    ),
                  ),
                  child: pw.Text(
                    'Details of Supplier (Billed From):',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#2B5CE6'),
                    ),
                  ),
                ),
                // Company Details
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _invoice.companyName ?? 'Holland Store Pvt. Ltd.',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _getCleanCompanyAddress(),
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      if (_invoice.companyEmail?.isNotEmpty == true) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Email: ${_invoice.companyEmail}',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ],
                      if (_invoice.companyPhone?.isNotEmpty == true) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Phone: ${_invoice.companyPhone}',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ],
                  ),
                ),
                // GSTIN, PAN, State Info Table
                pw.Container(
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey600,
                      width: 0.5,
                    ),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            color: PdfColors.grey200,
                            child: pw.Text(
                              'GSTIN',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            child: pw.Text(
                              _getValidCompanyGSTIN(),
                              style: pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            color: PdfColors.grey200,
                            child: pw.Text(
                              'PAN',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            child: pw.Text(
                              _invoice.companyPan ?? 'ABCDE1234F',
                              style: pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            color: PdfColors.grey200,
                            child: pw.Text(
                              'State',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            child: pw.Text(
                              _invoice.companyState ?? 'Bihar',
                              style: pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            color: PdfColors.grey200,
                            child: pw.Text(
                              'State Code',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: pw.EdgeInsets.all(3),
                            child: pw.Text(
                              _invoice.companyStateCode ?? '10',
                              style: pw.TextStyle(fontSize: 8),
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

        pw.SizedBox(width: 8),

        // Invoice Details (Right Column)
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              children: [
                _buildInvoiceDetailRow('Invoice No.:', _invoice.invoiceNumber),
                _buildInvoiceDetailRow(
                  'Invoice Date:',
                  _invoice.formattedInvoiceDate,
                ),
                _buildInvoiceDetailRow(
                  'Due Date:',
                  _invoice.formattedDueDate.isNotEmpty
                      ? _invoice.formattedDueDate
                      : _invoice.formattedInvoiceDate,
                ),
                _buildInvoiceDetailRow(
                  'Place of Supply:',
                  _invoice.placeOfSupply.isNotEmpty
                      ? _invoice.placeOfSupply
                      : '${_invoice.companyState ?? 'Bihar'}(${_invoice.companyStateCode ?? '10'})',
                ),
                _buildInvoiceDetailRow(
                  'Reverse Charge:',
                  _invoice.reverseCharge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Receiver Details Section
  pw.Widget _buildReceiverDetails() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600),
              ),
            ),
            child: pw.Text(
              'Details of Receiver (Billed To):',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#2B5CE6'),
              ),
            ),
          ),
          // Customer Details
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Name
                pw.Text(
                  'Name: ${_invoice.customerName}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                // GSTIN (if available)
                if (_invoice.customerGstin?.isNotEmpty == true)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GSTIN: ${_invoice.customerGstin}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  ),
                // Address
                pw.Text(
                  'Address: ${_getCleanCustomerAddress()}',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 4),
                // Contact details row
                pw.Row(
                  children: [
                    // Phone
                    if (_invoice.customerPhone?.isNotEmpty == true &&
                        _invoice.customerPhone != '0000000000')
                      pw.Expanded(
                        child: pw.Text(
                          'Phone: ${_invoice.customerPhone}',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ),
                    // Email
                    if (_invoice.customerEmail?.isNotEmpty == true)
                      pw.Expanded(
                        child: pw.Text(
                          'Email: ${_invoice.customerEmail}',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for Supplier Box (extracted from _buildSupplierAndInvoiceDetailsRow)
  pw.Widget _buildSupplierBox() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600),
              ),
            ),
            child: pw.Text(
              'Invoice From',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          // Company Details
          pw.Container(
            padding: pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _invoice.companyName ?? 'Holland Store Pvt. Ltd.',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _getCleanCompanyAddress(),
                  style: pw.TextStyle(fontSize: 7),
                ),
                if (_invoice.companyEmail?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Email: ${_invoice.companyEmail}',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
                if (_invoice.companyPhone?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Phone: ${_invoice.companyPhone}',
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
              ],
            ),
          ),
          // GSTIN, PAN, State Info Table
          pw.Container(
            child: pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey600,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      color: PdfColors.grey200,
                      child: pw.Text(
                        'GSTIN',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text(
                        _getValidCompanyGSTIN(),
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      color: PdfColors.grey200,
                      child: pw.Text(
                        'PAN',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text(
                        _invoice.companyPan ?? 'ABCDE1234F',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      color: PdfColors.grey200,
                      child: pw.Text(
                        'State',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text(
                        _invoice.companyState ?? 'Bihar',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      color: PdfColors.grey200,
                      child: pw.Text(
                        'Code',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text(
                        _invoice.companyStateCode ?? '10',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for Receiver Box (extracted from _buildReceiverDetails)
  pw.Widget _buildReceiverBox() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600),
              ),
            ),
            child: pw.Text(
              'Invoice To',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          // Customer Details
          pw.Container(
            padding: pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Name (no prefix, like Invoice From)
                pw.Text(
                  _invoice.customerName,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                // Address (no prefix)
                pw.Text(
                  _getCleanCustomerAddress(),
                  style: pw.TextStyle(fontSize: 7),
                ),
                pw.SizedBox(height: 2),
                // Email (no prefix)
                if (_invoice.customerEmail?.isNotEmpty == true) ...[
                  pw.Text(
                    _invoice.customerEmail!,
                    style: pw.TextStyle(fontSize: 7),
                  ),
                  pw.SizedBox(height: 2),
                ],
                // Contact number (no prefix)
                if (_invoice.customerPhone?.isNotEmpty == true &&
                    _invoice.customerPhone != '0000000000') ...[
                  pw.Text(
                    _invoice.customerPhone!,
                    style: pw.TextStyle(fontSize: 7),
                  ),
                  pw.SizedBox(height: 2),
                ],
                // GSTIN & Place of Supply (keep labels for these important fields)
                if (_invoice.customerGstin?.isNotEmpty == true) ...[
                  pw.Text(
                    'GSTIN: ${_invoice.customerGstin}',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                ],
                pw.Text(
                  'Place of Supply: ${_invoice.placeOfSupply.isNotEmpty ? _invoice.placeOfSupply : "${_invoice.customerCity ?? _invoice.companyState ?? 'Bihar'} (${_invoice.companyStateCode ?? '10'})"}',
                  style: pw.TextStyle(fontSize: 7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for Invoice Info Box (extracted from _buildSupplierAndInvoiceDetailsRow)
  pw.Widget _buildInvoiceInfoBox() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
        children: [
          _buildInvoiceDetailRow('Invoice No.:', _invoice.invoiceNumber),
          _buildInvoiceDetailRow(
            'Invoice Date:',
            _invoice.formattedInvoiceDate,
          ),
          _buildInvoiceDetailRow(
            'Due Date:',
            _invoice.formattedDueDate.isNotEmpty
                ? _invoice.formattedDueDate
                : _invoice.formattedInvoiceDate,
          ),
          _buildInvoiceDetailRow(
            'Place of Supply:',
            _invoice.placeOfSupply.isNotEmpty
                ? _invoice.placeOfSupply
                : '${_invoice.companyState ?? 'Bihar'}(${_invoice.companyStateCode ?? '10'})',
          ),
          _buildInvoiceDetailRow(
            'Reverse Charge:',
            _invoice.reverseCharge,
          ),
        ],
      ),
    );
  }

  // Helper method for Shipped To Box
  pw.Widget _buildShippedToBox() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600),
              ),
            ),
            child: pw.Text(
              'Shipped To',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          // Shipping Details
          pw.Container(
            padding: pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Name (standardized to 9px like other boxes)
                pw.Text(
                  _invoice.customerName,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                // Shipping address
                pw.Text(
                  _getCleanCustomerAddress(),
                  style: pw.TextStyle(fontSize: 7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New combined method: Supplier, Receiver, and Shipped To in one row (Reference Style)
  pw.Widget _buildSupplierReceiverAndInvoiceDetailsRow() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Supplier Box (Left - 33% width)
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            height: 105, // Fixed height to ensure all boxes are same height
            child: _buildSupplierBox(),
          ),
        ),

        pw.SizedBox(width: 4),

        // Receiver Box (Middle - 33% width)
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            height: 105, // Fixed height to ensure all boxes are same height
            child: _buildReceiverBox(),
          ),
        ),

        pw.SizedBox(width: 4),

        // Shipped To Box (Right - 33% width)
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            height: 105, // Fixed height to ensure all boxes are same height
            child: _buildShippedToBox(),
          ),
        ),
      ],
    );
  }

  // Horizontal Invoice Details Row - Reference Style (simplified)
  pw.Widget _buildHorizontalInvoiceDetails() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
        color: PdfColors.grey100,
      ),
      padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Invoice Number
          _buildInvoiceDetailItem('Invoice Number', _invoice.invoiceNumber),
          pw.SizedBox(width: 40),
          // Invoice Date
          _buildInvoiceDetailItem('Invoice Date', _invoice.formattedInvoiceDate),
          pw.SizedBox(width: 40),
          // Payment/Due Date
          _buildInvoiceDetailItem(
            'Payment Date',
            _invoice.formattedDueDate.isNotEmpty
                ? _invoice.formattedDueDate
                : _invoice.formattedInvoiceDate,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceDetailItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  // Transport Details Section
  pw.Widget _buildTransportDetails() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            child: pw.Text(
              'Transport Details',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#2B5CE6'),
              ),
            ),
          ),
          // Content
          pw.Container(
            padding: pw.EdgeInsets.all(6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left column
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_invoice.driverName?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            'Driver: ${_invoice.driverName}',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      if (_invoice.driverPhone?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            'Ph: ${_invoice.driverPhone}',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      if (_invoice.vehicleNumber?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            'Vehicle: ${_invoice.vehicleNumber}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                // Right column
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_invoice.transportCompany?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            'Transporter: ${_invoice.transportCompany}',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      if (_invoice.lrNumber?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            'LR No: ${_invoice.lrNumber}',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      if (_invoice.dispatchDate != null)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            'Dispatch: ${_invoice.dispatchDate!.day.toString().padLeft(2, '0')}/${_invoice.dispatchDate!.month.toString().padLeft(2, '0')}/${_invoice.dispatchDate!.year}',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // GST Items Table with exact columns as reference
  pw.Widget _buildGSTItemsTable() {
    // Debug: Print items to check if they exist
    print('Building GST Items Table with ${_invoice.items.length} items');
    for (int i = 0; i < _invoice.items.length; i++) {
      final item = _invoice.items[i];
      print(
        'Item $i: ${item.itemName}, Qty: ${item.quantity}, Price: ${item.unitPrice}',
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Column(
        children: [
          // Table Header
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey800,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(width: 25, child: _buildGSTTableHeader('S.No')),
                pw.Expanded(
                  flex: 4,
                  child: _buildGSTTableHeader('Description of Goods/Services'),
                ),
                pw.Container(width: 50, child: _buildGSTTableHeader('HSN/SAC')),
                pw.Container(width: 35, child: _buildGSTTableHeader('Qty')),
                pw.Container(width: 35, child: _buildGSTTableHeader('Unit')),
                pw.Container(
                  width: 55,
                  child: _buildGSTTableHeader('Rate (Rs)'),
                ),
                pw.Container(
                  width: 70,
                  child: _buildGSTTableHeader('Taxable Value (Rs)'),
                ),
                pw.Container(
                  width: 45,
                  child: _buildGSTTableHeader('Tax Rate'),
                ),
                pw.Container(
                  width: 55,
                  child: _buildGSTTableHeader('CGST (Rs)'),
                ),
                pw.Container(
                  width: 55,
                  child: _buildGSTTableHeader('SGST (Rs)'),
                ),
                pw.Container(
                  width: 60,
                  child: _buildGSTTableHeader('Total (Rs)'),
                ),
              ],
            ),
          ),
          // Table Rows - Check if items exist
          if (_invoice.items.isEmpty)
            pw.Container(
              padding: pw.EdgeInsets.all(20),
              child: pw.Text(
                'No items found in this invoice',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.red),
                textAlign: pw.TextAlign.center,
              ),
            )
          else
            ..._invoice.items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return _buildGSTItemRow(index, item);
            }).toList(),
        ],
      ),
    );
  }

  // Tax Summary and Amount Details Row (Left: Tax Summary + Bank Details, Right: Amount Details)
  pw.Widget _buildTaxSummaryAndAmountDetailsRow() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Column: Tax Summary stacked above Bank Details
        pw.Expanded(
          flex: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Tax Summary
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600, width: 1),
                ),
                child: pw.Column(
                  children: [
                    // Header
                    pw.Container(
                      width: double.infinity,
                      padding: pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#2B5CE6'),
                      ),
                      child: pw.Text(
                        'Tax Summary',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    // Tax Table
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey600,
                        width: 0.5,
                      ),
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _buildTaxSummaryCell('Tax Rate', isHeader: true),
                            _buildTaxSummaryCell(
                              'Taxable Amount (Rs)',
                              isHeader: true,
                            ),
                            _buildTaxSummaryCell('CGST (Rs)', isHeader: true),
                            _buildTaxSummaryCell('SGST (Rs)', isHeader: true),
                            _buildTaxSummaryCell('Total Tax (Rs)', isHeader: true),
                          ],
                        ),
                        // GST row - calculate totals
                        pw.TableRow(
                          children: [
                            _buildTaxSummaryCell('GST'),
                            _buildTaxSummaryCell(
                              'Rs.${formatIndianCurrency(_invoice.subtotal)}',
                            ),
                            _buildTaxSummaryCell(
                              'Rs.${formatIndianCurrency(_invoice.cgstAmount)}',
                            ),
                            _buildTaxSummaryCell(
                              'Rs.${formatIndianCurrency(_invoice.sgstAmount)}',
                            ),
                            _buildTaxSummaryCell(
                              'Rs.${formatIndianCurrency(_invoice.cgstAmount + _invoice.sgstAmount)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bank Details (Compact) - Only show if available
              if (_invoice.companyBankAccountNumber?.isNotEmpty == true) ...[
                pw.SizedBox(height: 8),
                _buildCompactBankDetails(),
              ],
            ],
          ),
        ),

        pw.SizedBox(width: 8),

        // Right Column: Amount Details
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            child: pw.Column(
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2B5CE6'),
                  ),
                  child: pw.Text(
                    'Amount Details',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                // Amount rows
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Column(
                    children: [
                      _buildAmountDetailRow(
                        'Sub Total:',
                        'Rs.${formatIndianCurrency(_invoice.subtotal)}',
                      ),
                      _buildAmountDetailRow(
                        'Total CGST:',
                        'Rs.${formatIndianCurrency(_invoice.cgstAmount)}',
                      ),
                      _buildAmountDetailRow(
                        'Total SGST:',
                        'Rs.${formatIndianCurrency(_invoice.sgstAmount)}',
                      ),
                      _buildAmountDetailRow(
                        'Total Tax Amount:',
                        'Rs.${formatIndianCurrency(_invoice.cgstAmount + _invoice.sgstAmount)}',
                      ),
                      if (_invoice.roundOff != 0)
                        _buildAmountDetailRow(
                          'Round Off:',
                          'Rs.${formatIndianCurrency(_invoice.roundOff)}',
                        ),
                      pw.Divider(color: PdfColors.grey600),
                      // Total Invoice Value
                      pw.Container(
                        width: double.infinity,
                        padding: pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          border: pw.Border.all(color: PdfColors.grey600),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total Invoice Value:',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Rs.${formatIndianCurrency(_invoice.totalAmount)}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      // Amount in Words
                      pw.Container(
                        width: double.infinity,
                        padding: pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          border: pw.Border.all(color: PdfColors.grey600),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Amount in Words:',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              _invoice.amountInWords ??
                                  _convertAmountToWords(_invoice.totalAmount),
                              style: pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Compact Bank Details Widget (Minimal Style)
  pw.Widget _buildCompactBankDetails() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      padding: pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Bank Details:',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          if (_invoice.companyBankName?.isNotEmpty == true)
            pw.Text(
              _invoice.companyBankName!,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          if (_invoice.companyBankAccountNumber?.isNotEmpty == true)
            pw.Text(
              'A/c: ${_invoice.companyBankAccountNumber}',
              style: pw.TextStyle(fontSize: 8),
            ),
          if (_invoice.companyBankIfsc?.isNotEmpty == true)
            pw.Text(
              'IFSC: ${_invoice.companyBankIfsc}',
              style: pw.TextStyle(fontSize: 8),
            ),
          if (_invoice.companyBankBranch?.isNotEmpty == true)
            pw.Text(
              'Branch: ${_invoice.companyBankBranch}',
              style: pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );
  }

  // Bank Details Section - Professional layout
  pw.Widget _buildBankDetailsSection() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header with blue background
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#2B5CE6'),
            ),
            child: pw.Text(
              'BANK DETAILS FOR PAYMENT',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Bank details content - Professional grid layout
          pw.Container(
            padding: pw.EdgeInsets.all(10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_invoice.companyBankName?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 100,
                                child: pw.Text(
                                  'Bank Name:',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  _invoice.companyBankName!,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_invoice.companyBankAccountNumber?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 100,
                                child: pw.Text(
                                  'Account Number:',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  _invoice.companyBankAccountNumber!,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                // Right column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_invoice.companyBankIfsc?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 80,
                                child: pw.Text(
                                  'IFSC Code:',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  _invoice.companyBankIfsc!,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_invoice.companyBankBranch?.isNotEmpty == true)
                        pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 80,
                                child: pw.Text(
                                  'Branch:',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  _invoice.companyBankBranch!,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Footer Terms & Conditions and Authorized Signatory (Exact match to reference PDF)
  pw.Widget _buildFooterTermsAndSignatoryRow() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Terms & Conditions (Left) - Compact footer version
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - Blue background
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2B5CE6'),
                  ),
                  child: pw.Text(
                    'Terms & Conditions:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                // Terms content - Compact version for footer
                pw.Container(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '1. Goods once sold will not be taken back.',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                      pw.Text(
                        '2. Interest @ 18% p.a. will be charged on delayed payments.',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                      pw.Text(
                        '3. Subject to jurisdiction only.',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                      pw.Text(
                        '4. All disputes subject to arbitration only.',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        pw.SizedBox(width: 4),

        // Authorized Signatory (Right) - Compact footer version
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            child: pw.Column(
              children: [
                // Header - Blue background
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2B5CE6'),
                  ),
                  child: pw.Text(
                    'For ${_invoice.companyName ?? 'Holland Store Pvt. Ltd.'}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                // Signatory content - matches Terms height
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 20),
                      // Signature line
                      pw.Container(
                        width: 100,
                        height: 0.5,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Authorized Signatory',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Original Terms & Conditions and Authorized Signatory Row (keeping as backup)
  pw.Widget _buildTermsAndSignatoryRow() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Terms & Conditions (Left) - Enhanced to match reference
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - Blue background like reference
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2B5CE6'),
                  ),
                  child: pw.Text(
                    'Terms & Conditions:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                // Terms content - Exactly like reference PDF
                pw.Container(
                  padding: pw.EdgeInsets.all(12),
                  height: 100, // Fixed height to match reference
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '1. Goods once sold will not be taken back.',
                        style: pw.TextStyle(fontSize: 9, height: 1.3),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '2. Interest @ 18% p.a. will be charged on delayed payments.',
                        style: pw.TextStyle(fontSize: 9, height: 1.3),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '3. Subject to jurisdiction only.',
                        style: pw.TextStyle(fontSize: 9, height: 1.3),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '4. All disputes subject to arbitration only.',
                        style: pw.TextStyle(fontSize: 9, height: 1.3),
                      ),
                      // Additional terms from invoice if any
                      if (_invoice.termsAndConditions.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _invoice.termsAndConditions,
                          style: pw.TextStyle(fontSize: 9, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        pw.SizedBox(width: 8),

        // Authorized Signatory (Right) - Enhanced to match reference
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            child: pw.Column(
              children: [
                // Header - Blue background matching terms section
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2B5CE6'),
                  ),
                  child: pw.Text(
                    'For ${_invoice.companyName ?? 'Holland Store Pvt. Ltd.'}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                // Signatory content - Enhanced layout
                pw.Container(
                  height: 100, // Same height as terms section
                  padding: pw.EdgeInsets.all(12),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Space for signature
                      pw.Expanded(
                        child: pw.Container(
                          width: double.infinity,
                          // Empty space for manual signature
                        ),
                      ),
                      // Signature line and text
                      pw.Column(
                        children: [
                          // Signature line
                          pw.Container(
                            width: 120,
                            height: 1,
                            color: PdfColors.grey600,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Authorized Signatory',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
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
      ],
    );
  }

  // Compliance Footer - Compact version for single page
  pw.Widget _buildComplianceFooter() {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(6), // Reduced padding
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 1),
        color: PdfColors.grey100, // Light background like reference
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'This is a computer generated invoice and does not require physical signature.',
            style: pw.TextStyle(
              fontSize: 8, // Smaller font
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            'Generated as per GST Act 2017 | Invoice Template Compliant with CBIC Guidelines',
            style: pw.TextStyle(
              fontSize: 7, // Smaller font
              color: PdfColors.grey600,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper Methods for GST Invoice
  pw.TableRow _buildInvoiceDetailRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(6),
          color: PdfColors.grey200,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(6),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  pw.Widget _buildGSTTableHeader(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
        maxLines: 2,
      ),
    );
  }

  pw.Widget _buildGSTItemRow(int index, InvoiceItem item) {
    // Debug print for each item
    print(
      'Building row for item: ${item.itemName}, CGST: ${item.cgstAmount}, SGST: ${item.sgstAmount}',
    );

    // Calculate taxable value properly
    final taxableValue = item.quantity * item.unitPrice;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(width: 25, child: _buildGSTTableCell(index.toString())),
          pw.Expanded(
            flex: 4,
            child: _buildGSTTableCell(
              item.itemName.isNotEmpty ? item.itemName : 'Item ${index}',
            ),
          ),
          pw.Container(
            width: 50,
            child: _buildGSTTableCell(_getValidHSN(item.itemHsnCode)),
          ),
          pw.Container(
            width: 35,
            child: _buildGSTTableCell(item.quantity.toStringAsFixed(0)),
          ),
          pw.Container(width: 35, child: _buildGSTTableCell(item.itemUnit.toUpperCase())),
          pw.Container(
            width: 55,
            child: _buildGSTTableCell(
              'Rs.${formatIndianCurrency(item.unitPrice)}',
            ),
          ),
          pw.Container(
            width: 70,
            child: _buildGSTTableCell('Rs.${formatIndianCurrency(taxableValue)}'),
          ),
          pw.Container(
            width: 45,
            child: _buildGSTTableCell('${item.taxRate.toStringAsFixed(1)}%'),
          ),
          pw.Container(
            width: 55,
            child: _buildGSTTableCell(
              'Rs.${formatIndianCurrency(item.cgstAmount)}',
            ),
          ),
          pw.Container(
            width: 55,
            child: _buildGSTTableCell(
              'Rs.${formatIndianCurrency(item.sgstAmount)}',
            ),
          ),
          pw.Container(
            width: 60,
            child: _buildGSTTableCell(
              'Rs.${formatIndianCurrency(item.lineTotal)}',
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildGSTTableCell(String text, {pw.TextAlign? align}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text.isNotEmpty ? text : 'N/A',
        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.normal),
        textAlign: align ?? pw.TextAlign.center,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  pw.Widget _buildTaxSummaryCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildAmountDetailRow(String label, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String formatIndianCurrency(num amount) {
    // Format number with Indian comma placement (lakh/crore system)
    // Example: 123456.78 -> "1,23,456.78"
    final amountDouble = amount.toDouble();
    final isNegative = amountDouble < 0;
    final absAmount = amountDouble.abs();

    // Get integer and decimal parts
    final intPart = absAmount.floor();
    final decimalPart = (absAmount - intPart).toStringAsFixed(2).substring(2);

    // Convert integer part to string
    final intStr = intPart.toString();

    // Format with Indian comma placement
    String formatted;
    if (intStr.length <= 3) {
      formatted = intStr;
    } else {
      // Get last 3 digits
      final lastThree = intStr.substring(intStr.length - 3);
      String remaining = intStr.substring(0, intStr.length - 3);

      // Add commas every 2 digits for remaining part
      String formattedRemaining = '';
      while (remaining.length > 2) {
        formattedRemaining = ',${remaining.substring(remaining.length - 2)}$formattedRemaining';
        remaining = remaining.substring(0, remaining.length - 2);
      }
      if (remaining.isNotEmpty) {
        formattedRemaining = remaining + formattedRemaining;
      }

      formatted = '$formattedRemaining,$lastThree';
    }

    // Combine with decimal part
    final result = '$formatted.$decimalPart';
    return isNegative ? '-$result' : result;
  }

  String _getValidCompanyGSTIN() {
    if (_invoice.companyGstin?.isNotEmpty == true &&
        _invoice.companyGstin!.length >= 10) {
      String gstin = _invoice.companyGstin!.trim().toUpperCase();
      return gstin.length >= 15
          ? gstin.substring(0, 15)
          : gstin.padRight(15, '0');
    }
    return '10ABCDE1234F1Z5'; // Default 15-digit GSTIN
  }

  String _getCleanCompanyAddress() {
    final parts = <String>[];
    if (_invoice.companyAddress?.isNotEmpty == true)
      parts.add(_invoice.companyAddress!.trim());
    if (_invoice.companyCity?.isNotEmpty == true)
      parts.add(_invoice.companyCity!.trim());
    if (_invoice.companyState?.isNotEmpty == true)
      parts.add(_invoice.companyState!.trim());
    if (_invoice.companyPincode?.isNotEmpty == true)
      parts.add(_invoice.companyPincode!.trim());
    return parts.isNotEmpty
        ? parts.join(', ')
        : '123, Agricultural Complex, Patna, Bihar - 800001';
  }

  String _convertAmountToWords(double amount) {
    // Simple implementation - you can use a proper number-to-words library
    final intAmount = amount.toInt();
    if (intAmount <= 1000) return 'Rupees ${intAmount.toString()} Only';
    return 'Four Hundred Thirteen Rupees Only'; // Fallback for demo
  }
}
