import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/invoice.dart';
import '../../../shared/models/user.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../shared/widgets/custom_search_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../services/export_service_csv.dart';
import '../widgets/fy_selector_dropdown.dart';
import 'invoice_form_screen.dart';
import 'invoice_detail_screen.dart';
import 'invoice_settings_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;

      if (user != null) {
        context.read<InvoiceProvider>().fetchInvoices();
        context.read<InvoiceProvider>().fetchInvoiceStats();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      // Load more when user scrolls to 90% of the list
      context.read<InvoiceProvider>().loadMoreInvoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<InvoiceProvider, AuthProvider>(
      builder: (context, invoiceProvider, authProvider, child) {
        final user = authProvider.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please login to view invoices')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    elevation: 0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    pinned: true,
                    expandedHeight: user.isAdmin ? 295.h : 215.h,
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(60.h),
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: _buildResponsiveTabBar(invoiceProvider),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        color: Colors.white,
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            // App Bar Title - Fixed height to prevent overflow
                            Container(
                              height: 60.h,
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center, // Ensure proper alignment
                                  children: [
                                    Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1565C0),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long,
                                      color: Colors.white,
                                      size: 18.w,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center, // Center the content
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'GST Invoices',
                                            style: TextStyle(
                                              fontSize: 15.sp, // Slightly smaller to fit better
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                              height: 1.2, // Tighter line height
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(height: 1.h), // Minimal spacing
                                        Flexible(
                                          child: Text(
                                            'Tax Invoice Management',
                                            style: TextStyle(
                                              fontSize: 10.sp, // Slightly smaller
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w400,
                                              height: 1.1, // Very tight line height
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Actions
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!user.isAdmin) ...[
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1565C0),
                                            borderRadius: BorderRadius.circular(6.r),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.add, color: Colors.white),
                                            onPressed: () => _navigateToCreateInvoice(context),
                                            tooltip: 'Create New GST Invoice',
                                            padding: EdgeInsets.all(8.w),
                                            constraints: BoxConstraints(
                                              minWidth: 36.w,
                                              minHeight: 36.h,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                      ],
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                                        iconSize: 20.w,
                                        onSelected: (value) => _handleMenuAction(context, value, invoiceProvider),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'export',
                                            child: Row(
                                              children: [
                                                Icon(Icons.download, size: 18),
                                                SizedBox(width: 8),
                                                Text('Export Data'),
                                              ],
                                            ),
                                          ),
                                          // GST Report temporarily disabled due to Excel package conflicts
                                          // const PopupMenuItem(
                                          //   value: 'gst_report',
                                          //   child: Row(
                                          //     children: [
                                          //       Icon(Icons.assessment, size: 18),
                                          //       SizedBox(width: 8),
                                          //       Text('GST Report'),
                                          //     ],
                                          //   ),
                                          // ),
                                          const PopupMenuItem(
                                            value: 'settings',
                                            child: Row(
                                              children: [
                                                Icon(Icons.settings, size: 18),
                                                SizedBox(width: 8),
                                                Text('Settings'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Stats Cards for Admin
                            if (user.isAdmin) 
                              Container(
                                height: 120.h,
                                child: _buildResponsiveStatsCards(invoiceProvider),
                              ),
                            // Search and Filters - Give it fixed space
                            SizedBox(height: 8.h),
                            Container(
                              height: 95.h,
                              child: _buildResponsiveSearchAndFilters(),
                            ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: Container(
                color: const Color(0xFFFAFAFA),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildResponsiveInvoiceList(invoiceProvider.invoices, invoiceProvider),
                    _buildResponsiveInvoiceList(invoiceProvider.draftInvoices, invoiceProvider),
                    _buildResponsiveInvoiceList(invoiceProvider.sentInvoices, invoiceProvider),
                    _buildResponsiveInvoiceList(invoiceProvider.paidInvoices, invoiceProvider),
                    _buildResponsiveInvoiceList(invoiceProvider.overdueInvoices, invoiceProvider),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: user.isAdmin ? null : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () => _navigateToCreateInvoice(context),
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              label: const Text('New Invoice'),
              icon: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveStatsCards(InvoiceProvider provider) {
    // Use cached values from provider instead of recalculating
    final totalGST = provider.totalGST;
    final thisFYInvoices = provider.currentFYInvoicesCount;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cardSpacing = isTablet ? 16.w : 12.w;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use horizontal scrolling for very small screens
          if (constraints.maxWidth < 600) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCompactStatCard(
                    'Total Revenue',
                    NumberFormat('#,##,###').format(provider.totalRevenue),
                    '$thisFYInvoices this FY',
                    const Color(0xFF059669),
                    Icons.trending_up,
                    width: 160.w,
                    tabIndex: 3, // Paid tab
                  ),
                  SizedBox(width: cardSpacing),
                  _buildCompactStatCard(
                    'Tax Collected',
                    NumberFormat('#,##,###').format(totalGST),
                    'GST amount',
                    const Color(0xFF2563EB),
                    Icons.receipt_long,
                    width: 160.w,
                    tabIndex: 3, // Paid tab
                  ),
                  SizedBox(width: cardSpacing),
                  _buildCompactStatCard(
                    'Pending',
                    NumberFormat('#,##,###').format(provider.pendingAmount),
                    '${provider.sentInvoices.length} awaiting',
                    const Color(0xFFD97706),
                    Icons.schedule,
                    width: 160.w,
                    tabIndex: 2, // Sent tab
                  ),
                  SizedBox(width: cardSpacing),
                  _buildCompactStatCard(
                    'Overdue',
                    NumberFormat('#,##,###').format(provider.overdueAmount),
                    '${provider.overdueInvoices.length} past due',
                    const Color(0xFFDC2626),
                    Icons.warning_amber,
                    width: 160.w,
                    tabIndex: 4, // Overdue tab
                  ),
                ],
              ),
            );
          }
          
          // Use grid layout for larger screens
          return Row(
            children: [
              Expanded(
                child: _buildResponsiveStatCard(
                  'Total Revenue',
                  NumberFormat('#,##,###').format(provider.totalRevenue),
                  '$thisFYInvoices invoices this FY',
                  const Color(0xFF059669),
                  Icons.trending_up,
                  tabIndex: 3, // Paid tab
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _buildResponsiveStatCard(
                  'Tax Collected',
                  NumberFormat('#,##,###').format(totalGST),
                  'GST amount',
                  const Color(0xFF2563EB),
                  Icons.receipt_long,
                  tabIndex: 3, // Paid tab
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _buildResponsiveStatCard(
                  'Pending',
                  NumberFormat('#,##,###').format(provider.pendingAmount),
                  '${provider.sentInvoices.length} awaiting payment',
                  const Color(0xFFD97706),
                  Icons.schedule,
                  tabIndex: 2, // Sent tab
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _buildResponsiveStatCard(
                  'Overdue',
                  NumberFormat('#,##,###').format(provider.overdueAmount),
                  '${provider.overdueInvoices.length} past due',
                  const Color(0xFFDC2626),
                  Icons.warning_amber,
                  tabIndex: 4, // Overdue tab
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResponsiveStatCard(String title, String value, String subtitle, Color color, IconData icon, {required int tabIndex}) {
    return InkWell(
      onTap: () {
        _tabController.animateTo(tabIndex);
      },
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        constraints: BoxConstraints(minHeight: 100.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16.w,
                  ),
                ),
                const Spacer(),
              ],
            ),
            SizedBox(height: 8.h),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹$value',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[500],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatCard(String title, String value, String subtitle, Color color, IconData icon, {required double width, required int tabIndex}) {
    return InkWell(
      onTap: () {
        _tabController.animateTo(tabIndex);
      },
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: width,
        height: 85.h, // Fixed height instead of minHeight
        padding: EdgeInsets.all(10.w), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w), // Reduced padding
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 12.w, // Smaller icon
                  ),
                ),
                const Spacer(),
              ],
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹$value',
                  style: TextStyle(
                    fontSize: 13.sp, // Slightly smaller
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 9.sp, // Smaller text
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8.sp, // Smaller text
                color: Colors.grey[500],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveSearchAndFilters() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFFAFBFC),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF1565C0).withOpacity(0.12),
          width: 1.2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 400;
          return isSmall ? _buildVerticalSearchLayout() : _buildHorizontalSearchLayout();
        },
      ),
    );
  }

  Widget _buildHorizontalSearchLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Section Header
        Row(
          children: [
            Icon(
              Icons.filter_list_rounded,
              color: const Color(0xFF1565C0),
              size: 16.w,
            ),
            SizedBox(width: 6.w),
            Text(
              'Search & Filter',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1565C0),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),

        // Search Controls
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: _buildSearchField(),
            ),
            SizedBox(width: 12.w),
            _buildDateFilter(),
          ],
        ),
      ],
    );
  }

  Widget _buildVerticalSearchLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact search for small screens
        Row(
          children: [
            Expanded(
              child: _buildSearchField(),
            ),
            SizedBox(width: 12.w),
            _buildDateFilter(),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 42.h,
      child: CustomSearchBar(
        hint: '🔍 Search invoices by number, customer...',
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        onSubmitted: (value) {
          if (value.isEmpty) {
            context.read<InvoiceProvider>().fetchInvoices();
          } else {
            context.read<InvoiceProvider>().searchInvoices(value);
          }
        },
        initialValue: _searchQuery,
        borderRadius: 12.0,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        fillColor: Colors.grey.shade50,
        borderColor: Colors.grey.shade300,
        focusedBorderColor: const Color(0xFF1565C0),
        onClear: () {
          setState(() {
            _searchQuery = '';
          });
          context.read<InvoiceProvider>().fetchInvoices();
        },
      ),
    );
  }


  Widget _buildDateFilter() {
    return Container(
      height: 42.h, // Match search field height
      width: 42.h,  // Square aspect ratio
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            _showDateFilterDialog();
          },
          child: Center(
            child: Icon(
              Icons.calendar_today_rounded,
              color: const Color(0xFF1565C0),
              size: 18.w,
            ),
          ),
        ),
      ),
    );
  }

  void _showDateFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: const Color(0xFF1565C0), size: 24.w),
            SizedBox(width: 12.w),
            Text(
              'Filter by Date',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.today, color: const Color(0xFF1565C0)),
              title: Text('Today'),
              onTap: () {
                Navigator.pop(context);
                _applyDateFilter('today');
              },
            ),
            ListTile(
              leading: Icon(Icons.view_week, color: const Color(0xFF1565C0)),
              title: Text('This Week'),
              onTap: () {
                Navigator.pop(context);
                _applyDateFilter('week');
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_view_month, color: const Color(0xFF1565C0)),
              title: Text('This Month'),
              onTap: () {
                Navigator.pop(context);
                _applyDateFilter('month');
              },
            ),
            ListTile(
              leading: Icon(Icons.clear, color: Colors.orange),
              title: Text('Clear Filter'),
              onTap: () {
                Navigator.pop(context);
                _applyDateFilter('clear');
              },
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
    );
  }

  void _applyDateFilter(String filter) {
    // TODO: Implement date filtering logic
    _showSnackBar('Date filter: $filter applied', const Color(0xFF1565C0));
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  Widget _buildResponsiveTabBar(InvoiceProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isScrollable = screenWidth < 600;
        final isVeryCompact = screenWidth < 400;
        final isUltraCompact = screenWidth < 320;
        
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: 50.h,
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.grey[800],
            unselectedLabelColor: Colors.grey[500],
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            isScrollable: isScrollable,
            tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
            padding: EdgeInsets.symmetric(
              horizontal: isUltraCompact ? 4.w : (isVeryCompact ? 8.w : 16.w),
            ),
            labelPadding: EdgeInsets.symmetric(
              horizontal: isUltraCompact ? 6.w : (isVeryCompact ? 8.w : 12.w),
            ),
            labelStyle: TextStyle(
              fontSize: isUltraCompact ? 9.sp : (isVeryCompact ? 10.sp : 12.sp),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: isUltraCompact ? 9.sp : (isVeryCompact ? 10.sp : 12.sp),
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              _buildAdaptiveTab(
                'All',
                provider.totalInvoicesCount,
                Colors.grey[200]!,
                Colors.grey[700]!,
                isUltraCompact,
                isVeryCompact,
              ),
              _buildAdaptiveTab(
                'Draft',
                provider.draftInvoices.length,
                const Color(0xFF6B7280).withOpacity(0.1),
                const Color(0xFF6B7280),
                isUltraCompact,
                isVeryCompact,
              ),
              _buildAdaptiveTab(
                'Sent',
                provider.sentInvoices.length,
                const Color(0xFF2563EB).withOpacity(0.1),
                const Color(0xFF2563EB),
                isUltraCompact,
                isVeryCompact,
              ),
              _buildAdaptiveTab(
                'Paid',
                provider.paidInvoices.length,
                const Color(0xFF059669).withOpacity(0.1),
                const Color(0xFF059669),
                isUltraCompact,
                isVeryCompact,
              ),
              _buildAdaptiveTab(
                'Overdue',
                provider.overdueInvoices.length,
                const Color(0xFFEF4444).withOpacity(0.1),
                const Color(0xFFEF4444),
                isUltraCompact,
                isVeryCompact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveTab(String label, int count, Color badgeColor, Color textColor, bool isUltraCompact, bool isVeryCompact) {
    if (isUltraCompact) {
      // Ultra compact: Only show count badges
      return Tab(
        child: Container(
          constraints: BoxConstraints(
            minWidth: 35.w,
            maxWidth: 50.w,
            minHeight: 32.h,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                label.substring(0, 1), // First letter only
                style: TextStyle(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Tab(
      child: Container(
        constraints: BoxConstraints(
          minWidth: isVeryCompact ? 45.w : 60.w,
          maxWidth: isVeryCompact ? 75.w : 100.w,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: 2.w),
            Container(
              constraints: BoxConstraints(
                minWidth: 14.w,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 3.w,
                vertical: 1.h,
              ),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: isVeryCompact ? 7.sp : 8.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTab(String label, int count, Color badgeColor, Color textColor, bool isVeryCompact) {
    return Tab(
      child: Container(
        constraints: BoxConstraints(
          minWidth: isVeryCompact ? 50.w : 70.w,
          maxWidth: isVeryCompact ? 80.w : 120.w,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: isVeryCompact ? 3.w : 4.w),
            Container(
              constraints: BoxConstraints(
                minWidth: isVeryCompact ? 16.w : 20.w,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isVeryCompact ? 3.w : 4.w,
                vertical: 1.h,
              ),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: isVeryCompact ? 8.sp : 9.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveTab(String label, int count, Color badgeColor, Color textColor, bool isCompact) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: isCompact ? 4.w : 6.w),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 4.w : 6.w,
              vertical: 2.h,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: isCompact ? 9.sp : 11.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return const Color(0xFF6B7280); // Gray
      case InvoiceStatus.sent:
        return const Color(0xFF2563EB); // Blue
      case InvoiceStatus.paid:
        return const Color(0xFF059669); // Green
      case InvoiceStatus.cancelled:
        return const Color(0xFFDC2626); // Red
      case InvoiceStatus.overdue:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  Widget _buildResponsiveInvoiceList(List<Invoice> invoices, InvoiceProvider provider) {
    if (provider.isLoading) {
      return Container(
        padding: EdgeInsets.all(32.w),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading GST invoices...'),
            ],
          ),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Container(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64.w,
                color: Colors.red[300],
              ),
              SizedBox(height: 16.h),
              Text(
                'Error Loading Invoices',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                provider.errorMessage!,
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: () => provider.fetchInvoices(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Note: Search filtering is now done server-side via provider.searchInvoices()
    final filteredInvoices = invoices;

    if (filteredInvoices.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 48.w,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'No GST Invoices Found',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No invoices match your search criteria'
                    : 'Start by creating your first GST compliant invoice',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refreshInvoices(),
      color: const Color(0xFF2563EB),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= filteredInvoices.length) {
                    // Show loading indicator at the bottom
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final invoice = filteredInvoices[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _buildResponsiveInvoiceCard(invoice),
                  );
                },
                childCount: provider.hasMore ? filteredInvoices.length + 1 : filteredInvoices.length,
              ),
            ),
          ),
          // Add some bottom padding for the floating action button
          SliverPadding(
            padding: EdgeInsets.only(bottom: 80.h),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices, InvoiceProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              provider.errorMessage!,
              style: TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => provider.fetchInvoices(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Note: Search filtering is now done server-side via provider.searchInvoices()
    final filteredInvoices = invoices;

    if (filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64.w,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16.h),
            Text(
              'No invoices found',
              style: TextStyle(
                fontSize: 18.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchInvoices(),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: filteredInvoices.length,
        itemBuilder: (context, index) {
          final invoice = filteredInvoices[index];
          return _buildResponsiveInvoiceCard(invoice);
        },
      ),
    );
  }

  Widget _buildResponsiveInvoiceCard(Invoice invoice) {
    final isOverdue = invoice.status == InvoiceStatus.overdue;
    final statusColor = _getStatusColor(invoice.status);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isOverdue ? Colors.red.withOpacity(0.3) : Colors.grey[200]!,
              width: isOverdue ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isOverdue 
                    ? Colors.red.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _navigateToInvoiceDetail(invoice),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 14.w : 18.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            invoice.invoiceNumber,
                            style: TextStyle(
                              fontSize: isCompact ? 12.sp : 14.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      _buildResponsiveStatusChip(invoice.status, isCompact),
                    ],
                  ),
                  
                  SizedBox(height: 12.h),
                  
                  // Customer Information
                  Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 16.w,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          invoice.customerName,
                          style: TextStyle(
                            fontSize: isCompact ? 14.sp : 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Always show GSTIN row for GST compliance visibility
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(
                        invoice.customerGstin != null && invoice.customerGstin!.isNotEmpty
                            ? Icons.verified_user_rounded
                            : Icons.info_outline_rounded,
                        size: 14.w,
                        color: invoice.customerGstin != null && invoice.customerGstin!.isNotEmpty
                            ? Colors.green[600]
                            : Colors.grey[500],
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          'GSTIN: ${invoice.customerGstin != null && invoice.customerGstin!.isNotEmpty ? invoice.customerGstin : 'Not Provided'}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: invoice.customerGstin != null && invoice.customerGstin!.isNotEmpty
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12.h),
                  
                  // Amount Section - Responsive Layout
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: isCompact
                        ? _buildCompactAmountSection(invoice)
                        : _buildFullAmountSection(invoice),
                  ),
                  
                  SizedBox(height: 12.h),
                  
                  // Footer Information
                  _buildInvoiceFooter(invoice, isOverdue, isCompact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactAmountSection(Invoice invoice) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Amount',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              '₹${NumberFormat('#,##,###').format(invoice.totalAmount)}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        // Show tax based on actual amounts (IGST or CGST+SGST)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              invoice.igstAmount > 0
                  ? 'IGST'
                  : (invoice.cgstAmount > 0 || invoice.sgstAmount > 0)
                      ? 'CGST + SGST'
                      : 'Tax',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey[600],
              ),
            ),
            Text(
              invoice.igstAmount > 0
                  ? '₹${NumberFormat('#,##,###').format(invoice.igstAmount)}'
                  : (invoice.cgstAmount > 0 || invoice.sgstAmount > 0)
                      ? '₹${NumberFormat('#,##,###').format(invoice.cgstAmount + invoice.sgstAmount)}'
                      : 'Not Applicable',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey[600],
                fontStyle: (invoice.igstAmount > 0 || invoice.cgstAmount > 0 || invoice.sgstAmount > 0)
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullAmountSection(Invoice invoice) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subtotal',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '₹${NumberFormat('#,##,###').format(invoice.subtotal)}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        // Show tax breakdown based on actual amounts (IGST or CGST+SGST)
        if (invoice.igstAmount > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IGST',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '₹${NumberFormat('#,##,###').format(invoice.igstAmount)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
        if (invoice.cgstAmount > 0 || invoice.sgstAmount > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CGST',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '₹${NumberFormat('#,##,###').format(invoice.cgstAmount)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SGST',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '₹${NumberFormat('#,##,###').format(invoice.sgstAmount)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
        if (invoice.igstAmount == 0 && invoice.cgstAmount == 0 && invoice.sgstAmount == 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                'Not Applicable',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        Divider(height: 16.h, color: Colors.grey[300]),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Amount',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '₹${NumberFormat('#,##,###').format(invoice.totalAmount)}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceFooter(Invoice invoice, bool isOverdue, bool isCompact) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 12.w,
                color: Colors.grey[600],
              ),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  isCompact 
                      ? invoice.formattedInvoiceDate
                      : 'Date: ${invoice.formattedInvoiceDate}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (invoice.dueDate != null) ...[
          SizedBox(width: 8.w),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 12.w,
                color: isOverdue ? Colors.red[600] : Colors.grey[600],
              ),
              SizedBox(width: 4.w),
              Text(
                isCompact 
                    ? 'Due: ${invoice.formattedDueDate}'
                    : 'Due: ${invoice.formattedDueDate}',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isOverdue ? Colors.red[600] : Colors.grey[700],
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
        if (invoice.items.isNotEmpty) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              '${invoice.items.length} item${invoice.items.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 9.sp,
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResponsiveStatusChip(InvoiceStatus status, bool isCompact) {
    final color = _getStatusColor(status);
    final isUrgent = status == InvoiceStatus.overdue;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8.w : 10.w,
        vertical: isCompact ? 4.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 4.w : 6.w,
            height: isCompact ? 4.w : 6.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isCompact ? 4.w : 6.w),
          Text(
            status.displayName.toUpperCase(),
            style: TextStyle(
              fontSize: isCompact ? 8.sp : 10.sp,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          if (isUrgent && !isCompact) ...[
            SizedBox(width: 4.w),
            Icon(
              Icons.warning_rounded,
              size: 12.w,
              color: color,
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToCreateInvoice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InvoiceFormScreen(),
      ),
    );
  }

  void _navigateToInvoiceDetail(Invoice invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailScreen(invoice: invoice),
      ),
    );
  }

  /// Handle three-dot menu actions
  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    InvoiceProvider invoiceProvider,
  ) async {
    switch (action) {
      case 'export':
        await _handleExportData(context, invoiceProvider);
        break;
      case 'settings':
        await _handleSettings(context);
        break;
    }
  }

  /// Handle Export Data action
  Future<void> _handleExportData(
    BuildContext context,
    InvoiceProvider invoiceProvider,
  ) async {
    try {
      // Show FY picker dialog
      final result = await FYRangePickerDialog.show(context);

      if (result == null) return; // User cancelled

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating CSV file...'),
                  SizedBox(height: 8),
                  Text(
                    'Please wait while we prepare your invoice data',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Get invoices for the selected period
      final invoices = invoiceProvider.invoices;

      // Filter invoices by date range
      final startDate = result['startDate'] as DateTime;
      final endDate = result['endDate'] as DateTime;
      final filteredInvoices = invoices.where((invoice) {
        return invoice.invoiceDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               invoice.invoiceDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      if (filteredInvoices.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No invoices found for the selected period'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Generate CSV file
      final exportService = ExportService();
      final filePath = await exportService.exportToCSV(
        invoices: filteredInvoices,
        financialYear: result['fy'] ?? 'Custom',
        startDate: DateFormat('dd-MMM-yyyy').format(startDate),
        endDate: DateFormat('dd-MMM-yyyy').format(endDate),
      );

      Navigator.pop(context); // Close loading dialog

      // Show success dialog with options
      final shouldShare = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CSV file generated successfully!\n\nYou can open this file in Excel, Google Sheets, or any spreadsheet application.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Invoices: ${filteredInvoices.length}', style: TextStyle(fontSize: 12)),
                    Text(
                      'Period: ${DateFormat('dd-MMM-yyyy').format(startDate)} to ${DateFormat('dd-MMM-yyyy').format(endDate)}',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Done'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      );

      // Share file if requested
      if (shouldShare == true) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Invoice Export - ${result['fy'] ?? 'Custom Period'}',
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle Settings action
  Future<void> _handleSettings(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InvoiceSettingsScreen(),
      ),
    );

    // Refresh invoices if settings were updated
    if (result == true) {
      context.read<InvoiceProvider>().fetchInvoices();
    }
  }
}