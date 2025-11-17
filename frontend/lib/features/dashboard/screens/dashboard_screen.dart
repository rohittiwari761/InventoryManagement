import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../companies/screens/companies_screen.dart';
import '../../stores/screens/stores_screen.dart';
import '../../inventory/screens/items_screen.dart';
import '../../user_management/screens/users_screen.dart';
import '../../invoices/screens/invoices_screen.dart';
import '../../invoices/screens/invoice_form_screen.dart';
import '../../companies/screens/company_form_screen.dart';
import '../../inventory/screens/item_form_screen.dart';
import '../../stores/screens/store_form_screen.dart';
import '../../companies/providers/company_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../user_management/providers/user_management_provider.dart';
import '../../invoices/providers/invoice_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../auth/screens/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  List<Widget> _getScreensForUser(bool isAdmin) {
    if (isAdmin) {
      return [
        const DashboardHomeScreen(),
        const CompaniesScreen(),
        const StoresScreen(),
        const ItemsScreen(),
        const UsersScreen(),
        const InvoicesScreen(),
      ];
    } else {
      return [
        const DashboardHomeScreen(),
        const ItemsScreen(),
        const InvoicesScreen(),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItemsForUser(bool isAdmin) {
    if (isAdmin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: AppStrings.dashboard,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: AppStrings.companies,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: AppStrings.stores,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory),
          label: AppStrings.inventory,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Users',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt),
          label: AppStrings.invoices,
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: AppStrings.dashboard,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory),
          label: AppStrings.inventory,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt),
          label: AppStrings.invoices,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        final isAdmin = user?.isAdmin ?? false;
        
        final screens = _getScreensForUser(isAdmin);
        final navItems = _getNavItemsForUser(isAdmin);
        
        // Ensure selectedIndex is within bounds
        if (_selectedIndex >= screens.length) {
          _selectedIndex = 0;
        }
        
        return Scaffold(
          body: screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            items: navItems,
          ),
        );
      },
    );
  }

}

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    // Load data for all providers
    await Future.wait([
      context.read<CompanyProvider>().fetchCompanies(),
      context.read<StoreProvider>().fetchStores(),
      context.read<InventoryProvider>().fetchItems(),
      context.read<InvoiceProvider>().fetchInvoices(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.h),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            AppStrings.dashboard,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: Colors.grey.shade700,
                ),
                onPressed: () {},
              ),
            ),
            Container(
              margin: EdgeInsets.only(right: 12.w),
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.grey.shade700,
                    size: 20.w,
                  ),
                ),
                onSelected: (value) async {
                  if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  } else if (value == 'logout') {
                    await _handleLogout(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 20.w),
                        SizedBox(width: 12.w),
                        const Text(AppStrings.profile),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20.w, color: Colors.red),
                        SizedBox(width: 12.w),
                        Text(
                          AppStrings.logout,
                          style: TextStyle(color: Colors.red),
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
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;

          return RefreshIndicator(
            onRefresh: () async {
              await _loadDashboardData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section with Glassmorphism
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.9),
                                AppColors.primary.withOpacity(0.7),
                                AppColors.primary.withOpacity(0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
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
                                          'Welcome back,',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: Colors.white.withOpacity(0.95),
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          user?.displayName ?? 'User',
                                          style: TextStyle(
                                            fontSize: 22.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                            height: 1.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(12.w),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.15),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 24.w,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.25),
                                      Colors.white.withOpacity(0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24.r),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6.w),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        user?.isAdmin == true
                                            ? Icons.admin_panel_settings_rounded
                                            : Icons.store_rounded,
                                        color: Colors.white,
                                        size: 14.w,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      user?.isAdmin == true
                                          ? 'ADMIN'
                                          : user?.assignedStores.isNotEmpty == true
                                              ? user!.assignedStores.map((s) => s.name).join(', ')
                                              : 'STORE USER',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                SizedBox(height: 24.h),
                
                // Quick Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Overview',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _loadDashboardData();
                      },
                      icon: Icon(Icons.refresh, size: 18.w),
                      label: const Text('Refresh'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                Row(
                  children: [
                    Expanded(
                      child: Consumer<CompanyProvider>(
                        builder: (context, companyProvider, child) {
                          return _buildStatCard(
                            icon: Icons.business_rounded,
                            title: 'Companies',
                            value: '${companyProvider.companies.length}',
                            color: AppColors.dashboardCompanies,
                            bgColor: AppColors.dashboardCompaniesLight,
                            cardIndex: 0,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Consumer<StoreProvider>(
                        builder: (context, storeProvider, child) {
                          return _buildStatCard(
                            icon: Icons.store_rounded,
                            title: 'Stores',
                            value: '${storeProvider.stores.length}',
                            color: AppColors.dashboardStores,
                            bgColor: AppColors.dashboardStoresLight,
                            cardIndex: 1,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: Consumer<InventoryProvider>(
                        builder: (context, inventoryProvider, child) {
                          final totalItems = inventoryProvider.totalCount > 0
                              ? inventoryProvider.totalCount
                              : inventoryProvider.items.length;
                          return _buildStatCard(
                            icon: Icons.inventory_2_rounded,
                            title: 'Items',
                            value: '$totalItems',
                            color: AppColors.dashboardItems,
                            bgColor: AppColors.dashboardItemsLight,
                            cardIndex: 2,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Consumer<InvoiceProvider>(
                        builder: (context, invoiceProvider, child) {
                          final totalInvoices = invoiceProvider.totalCount > 0
                              ? invoiceProvider.totalCount
                              : invoiceProvider.invoices.length;
                          return _buildStatCard(
                            icon: Icons.receipt_long_rounded,
                            title: 'Invoices',
                            value: '$totalInvoices',
                            color: AppColors.dashboardInvoices,
                            bgColor: AppColors.dashboardInvoicesLight,
                            cardIndex: 3,
                          );
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 32.h),

                // Low Stock Alert Card
                if (user?.isAdmin == true)
                  Consumer<InventoryProvider>(
                    builder: (context, inventoryProvider, child) {
                      final lowStockCount = inventoryProvider.getLowStockItems().length;
                      if (lowStockCount > 0) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.orange.shade200,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700,
                                  size: 22.w,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Low Stock Alert',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '$lowStockCount items running low on stock',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey.shade400,
                                size: 16.w,
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                
                SizedBox(height: 32.h),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 16.h),
                
                if (user?.isAdmin == true) ...[
                  _buildActionCard(
                    icon: Icons.add_business,
                    title: 'Add Company',
                    subtitle: 'Create a new company',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompanyFormScreen(),
                        ),
                      ).then((_) {
                        // Refresh company data after adding
                        context.read<CompanyProvider>().fetchCompanies();
                      });
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.add_to_photos,
                    title: 'Add Item',
                    subtitle: 'Add new inventory item',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ItemFormScreen(),
                        ),
                      ).then((_) {
                        // Refresh inventory data after adding
                        context.read<InventoryProvider>().fetchItems();
                      });
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.add_location,
                    title: 'Add Store',
                    subtitle: 'Create a new store location',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoreFormScreen(),
                        ),
                      ).then((_) {
                        // Refresh store data after adding
                        context.read<StoreProvider>().fetchStores();
                      });
                    },
                  ),
                ],
                
                _buildActionCard(
                  icon: Icons.receipt_long,
                  title: 'Create Invoice',
                  subtitle: 'Generate new invoice',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InvoiceFormScreen(),
                      ),
                    ).then((_) {
                      // Refresh invoice data after creating
                      context.read<InvoiceProvider>().fetchInvoices();
                    });
                  },
                ),
                
                _buildActionCard(
                  icon: Icons.analytics,
                  title: 'View Reports',
                  subtitle: 'Check analytics and reports',
                  onTap: () {
                    // Navigate to invoices screen (reports section)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InvoicesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    int cardIndex = 0,
  }) {
    return _ProfessionalStatCard(
      icon: icon,
      title: title,
      value: value,
      color: color,
      bgColor: bgColor,
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
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
                  size: 20.w,
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
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade600,
                  size: 14.w,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show loading dialog using root navigator
    final dialogContext = context;
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(
        canPop: false,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    // Small delay to ensure dialog is shown
    await Future.delayed(const Duration(milliseconds: 100));

    try {

      // Clear all provider states first (with null checks)
      try {
        context.read<CompanyProvider>().clear();
      } catch (e) {
      }

      try {
        context.read<StoreProvider>().clear();
      } catch (e) {
      }

      try {
        context.read<InventoryProvider>().clear();
      } catch (e) {
      }

      try {
        context.read<UserManagementProvider>().clear();
      } catch (e) {
      }

      try {
        context.read<InvoiceProvider>().clear();
      } catch (e) {
      }

      try {
        context.read<CustomerProvider>().clear();
      } catch (e) {
      }

      // Close the dialog before logout to prevent context issues
      if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }

      // Small delay to ensure dialog is closed
      await Future.delayed(const Duration(milliseconds: 100));

      // Then logout from auth provider
      // This will trigger AuthWrapper to navigate to LoginScreen automatically
      await context.read<AuthProvider>().logout();

      // AuthWrapper in main.dart will handle navigation automatically

    } catch (e) {

      // Close dialog if still open
      try {
        if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
          Navigator.of(dialogContext, rootNavigator: true).pop();
        }
      } catch (dialogError) {
      }

      // Even if logout fails, force clear the auth state
      try {
        context.read<AuthProvider>().forceLogout();
      } catch (forceError) {
      }
    }
  }
}

// Clean Professional Stat Card - Simple & Effective
class _ProfessionalStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Color bgColor;

  const _ProfessionalStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20.w,
            ),
          ),
          SizedBox(height: 14.h),

          // Value - More subtle sizing
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.0,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 6.h),

          // Title - Clear and readable
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

