import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/api/api_client.dart';
import 'core/storage/storage_service.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/email_verification_pending_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/companies/providers/company_provider.dart';
import 'features/stores/providers/store_provider.dart';
import 'features/inventory/providers/inventory_provider.dart';
import 'features/user_management/providers/user_management_provider.dart';
import 'features/invoices/providers/invoice_provider.dart';
import 'features/invoices/providers/invoice_settings_provider.dart';
import 'features/customers/providers/customer_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize services
  await StorageService().initialize();
  ApiClient().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => CompanyProvider()),
            ChangeNotifierProvider(create: (_) => StoreProvider()),
            ChangeNotifierProvider(create: (_) => InventoryProvider()),
            ChangeNotifierProvider(create: (_) => UserManagementProvider()),
            ChangeNotifierProvider(create: (_) => InvoiceProvider()),
            ChangeNotifierProvider(create: (_) => InvoiceSettingsProvider()),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
          ],
          child: MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: AppColors.background,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                surface: AppColors.surface,
                onSurface: AppColors.onSurface,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
              useMaterial3: true,
            ),
            home: const AuthWrapper(),
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();

      // Set up authentication failed callback
      ApiClient().setAuthenticationFailedCallback(() {
        if (mounted) {
          _handleAuthenticationFailed();
        }
      });

      authProvider.checkAuthStatus();
    });
  }

  void _handleAuthenticationFailed() {
    // Clear all provider states
    context.read<AuthProvider>().forceLogout();
    context.read<CompanyProvider>().clear();
    context.read<StoreProvider>().clear();
    context.read<InventoryProvider>().clear();
    context.read<UserManagementProvider>().clear();
    context.read<InvoiceProvider>().clear();
    context.read<CustomerProvider>().clear();
  }

  /// Determines if email verification should be required for this user
  /// Based on email patterns that indicate admin/important users
  bool _shouldRequireEmailVerification(String email) {
    // Require email verification for admin users and important emails
    List<String> adminPatterns = [
      'admin@',
      'tiwari.rohit761@gmail.com', // Your specific email
      '@company.com', // Company domain
      'root@',
      'administrator@',
    ];

    // Check if email matches any admin pattern
    bool isAdminEmail = adminPatterns.any(
      (pattern) => email.toLowerCase().contains(pattern.toLowerCase()),
    );

    return isAdminEmail;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated) {
          final user = authProvider.user;

          // Check if user needs email verification
          if (user != null &&
              !user.isVerified &&
              _shouldRequireEmailVerification(user.email)) {
            return EmailVerificationPendingScreen(email: user.email);
          }

          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
