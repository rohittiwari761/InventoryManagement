import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();

      // Capture navigator BEFORE async call to ensure it's valid
      final navigator = Navigator.of(context, rootNavigator: true);

      // Clear any previous errors
      authProvider.clearError();

      final result = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      print('DEBUG LoginScreen: Login result = $result'); // Debug

      // Check if user needs to verify email
      if (result['unverified'] == true) {
        // Use captured navigator from before async call
        // Use push (not pushReplacement) so AuthWrapper stays in stack
        navigator.push(
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: result['email'] as String,
            ),
          ),
        );
        return;
      }

      // Check if account is pending approval
      if (result['pending_approval'] == true) {
        print('DEBUG LoginScreen: pending_approval is true, mounted=$mounted'); // Debug
        if (mounted) {
          // Use post-frame callback to show dialog after any rebuilds complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('DEBUG LoginScreen: Showing pending approval dialog'); // Debug
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  icon: Icon(
                    Icons.pending_outlined,
                    color: AppColors.warning,
                    size: 48.w,
                  ),
                  title: const Text('Approval Required'),
                  content: Text(
                    result['message'] as String? ??
                    'Your account is pending admin approval. Please contact your administrator.',
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            } else {
              print('DEBUG LoginScreen: Widget unmounted, cannot show dialog'); // Debug
            }
          });
        } else {
          print('DEBUG LoginScreen: Widget not mounted, skipping dialog'); // Debug
        }
        return;
      }

      // Check if account is rejected
      if (result['rejected'] == true) {
        print('DEBUG LoginScreen: rejected is true, mounted=$mounted'); // Debug
        if (mounted) {
          // Use post-frame callback to show dialog after any rebuilds complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('DEBUG LoginScreen: Showing rejected account dialog'); // Debug
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: AppColors.error,
                    size: 48.w,
                  ),
                  title: const Text('Access Denied'),
                  content: Text(
                    result['message'] as String? ??
                    'Your account access has been denied. Please contact your administrator.',
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            } else {
              print('DEBUG LoginScreen: Widget unmounted, cannot show dialog'); // Debug
            }
          });
        } else {
          print('DEBUG LoginScreen: Widget not mounted, skipping dialog'); // Debug
        }
        return;
      }

      // Handle regular login failure
      if (result['success'] != true) {
        if (mounted) {
          String errorMsg = authProvider.errorMessage ?? 'Login failed';

          // Provide more user-friendly error messages
          if (errorMsg.contains('Invalid email or password') ||
              errorMsg.contains('Invalid credentials')) {
            errorMsg = '❌ Invalid email or password. Please check your credentials.';
          } else if (errorMsg.contains('Network error')) {
            errorMsg = '🌐 Network error. Please check your connection.';
          } else if (errorMsg.contains('unexpected error')) {
            errorMsg = '⚠️ Something went wrong. Please try again.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 60.h),
              
              // App Logo/Title
              Icon(
                Icons.inventory_2,
                size: 80.w,
                color: AppColors.primary,
              ),
              SizedBox(height: 16.h),
              Text(
                AppStrings.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Manage your inventory efficiently',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              
              SizedBox(height: 60.h),
              
              // Login Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.login,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppStrings.fieldRequired;
                        }
                        if (!EmailValidator.validate(value)) {
                          return AppStrings.invalidEmail;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: AppStrings.password,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword 
                                ? Icons.visibility_off 
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppStrings.fieldRequired;
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 8.h),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Error message display
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        if (authProvider.errorMessage != null) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 16.h),
                            padding: EdgeInsets.all(12.w),
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
                                    authProvider.errorMessage!,
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    
                    // Login Button
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        return ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _login,
                          child: authProvider.isLoading
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.onPrimary,
                                    ),
                                  ),
                                )
                              : Text(
                                  AppStrings.login,
                                  style: TextStyle(fontSize: 16.sp),
                                ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            AppStrings.register,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
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
}