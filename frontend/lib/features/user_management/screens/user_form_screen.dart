import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/user.dart';
import '../providers/user_management_provider.dart';
import '../../stores/providers/store_provider.dart';

class UserFormScreen extends StatefulWidget {
  final User? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'store_user';
  int? _selectedStoreId;
  List<int> _assignedStoreIds = [];
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStores();
      if (isEditing) {
        _loadUserStoreAssignments();
      }
    });
    if (isEditing) {
      _initializeFormWithUser();
    }
  }

  void _initializeFormWithUser() {
    final user = widget.user!;
    _emailController.text = user.email;
    _usernameController.text = user.username;
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _phoneController.text = user.phone ?? '';
    _selectedRole = user.role;
    _isActive = user.isActive;
  }

  Future<void> _loadUserStoreAssignments() async {
    if (widget.user != null) {
      try {
        final provider = context.read<UserManagementProvider>();
        final userStores = await provider.getUserStores(widget.user!.id);
        
        setState(() {
          _assignedStoreIds = userStores
              .where((store) => store['is_active'] == true)
              .map<int>((store) => store['store_id'] as int)
              .toList();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load store assignments: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit User' : 'Create User'),
        actions: [
          TextButton(
            onPressed: _saveUser,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<UserManagementProvider>(
        builder: (context, provider, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      margin: EdgeInsets.only(bottom: 16.h),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.error),
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
                              provider.errorMessage!,
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: provider.clearError,
                            icon: Icon(
                              Icons.close,
                              color: AppColors.error,
                              size: 20.w,
                            ),
                          ),
                        ],
                      ),
                    ),

                  _buildSection(
                    'Personal Information',
                    [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _firstNameController,
                              label: 'First Name',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'First name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: _buildTextField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Last name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone (Optional)',
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  _buildSection(
                    'Account Information',
                    [
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!EmailValidator.validate(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        enabled: !isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Username is required';
                          }
                          if (value.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      _buildRoleDropdown(),
                      if (!isEditing) ...[
                        SizedBox(height: 16.h),
                        _buildStoreDropdown(),
                      ],
                      if (isEditing) ...[
                        SizedBox(height: 16.h),
                        _buildStoreAssignments(),
                        SizedBox(height: 16.h),
                        _buildActiveSwitch(),
                      ],
                    ],
                  ),

                  if (!isEditing) ...[
                    SizedBox(height: 24.h),
                    _buildSection(
                      'Security',
                      [
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16.h),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 32.h),

                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _saveUser,
                      child: provider.isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              isEditing ? 'Update User' : 'Create User',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.error),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: InputDecoration(
        labelText: 'Role',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'admin',
          child: Text('Admin'),
        ),
        DropdownMenuItem(
          value: 'store_user',
          child: Text('Store User'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedRole = value;
          });
        }
      },
    );
  }

  Widget _buildStoreDropdown() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        if (storeProvider.isLoading) {
          return Container(
            height: 56.h,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12.w),
                const Text('Loading stores...'),
              ],
            ),
          );
        }

        if (storeProvider.stores.isEmpty) {
          return Container(
            height: 56.h,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.error),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: AppColors.error, size: 20.w),
                SizedBox(width: 12.w),
                Text(
                  'No stores available. Create a store first.',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
            ),
          );
        }

        return DropdownButtonFormField<int?>(
          value: _selectedStoreId,
          decoration: InputDecoration(
            labelText: 'Assign to Store (Optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
          hint: const Text('Select a store'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('No store assignment'),
            ),
            ...storeProvider.stores.map((store) => DropdownMenuItem<int?>(
              value: store.id,
              child: Text(store.name),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedStoreId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildStoreAssignments() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        if (storeProvider.isLoading) {
          return Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12.w),
                const Text('Loading stores...'),
              ],
            ),
          );
        }

        if (storeProvider.stores.isEmpty) {
          return Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.error),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: AppColors.error, size: 20.w),
                SizedBox(width: 12.w),
                Text(
                  'No stores available. Create a store first.',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Assignments',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Select stores this user can access',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: storeProvider.stores.map((store) {
                  final isAssigned = _assignedStoreIds.contains(store.id);
                  return CheckboxListTile(
                    title: Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      store.address ?? 'No address provided',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: isAssigned,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          if (!_assignedStoreIds.contains(store.id)) {
                            _assignedStoreIds.add(store.id);
                          }
                        } else {
                          _assignedStoreIds.remove(store.id);
                        }
                      });
                    },
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveSwitch() {
    return Row(
      children: [
        Text(
          'Active Status',
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Switch(
          value: _isActive,
          onChanged: (value) {
            setState(() {
              _isActive = value;
            });
          },
          activeColor: AppColors.success,
        ),
      ],
    );
  }

  Future<void> _updateUserStoreAssignments(UserManagementProvider provider, int userId) async {
    try {
      // Get current store assignments
      final currentStores = await provider.getUserStores(userId);
      final currentStoreIds = currentStores
          .where((store) => store['is_active'] == true)
          .map<int>((store) => store['store_id'] as int)
          .toSet();
      
      final newStoreIds = _assignedStoreIds.toSet();
      
      // Find stores to add (in new list but not in current)
      final storesToAdd = newStoreIds.difference(currentStoreIds);
      
      // Find stores to remove (in current list but not in new)
      final storesToRemove = currentStoreIds.difference(newStoreIds);
      
      // Add new store assignments
      for (int storeId in storesToAdd) {
        final success = await provider.assignUserToStore(userId, storeId);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign user to store ID: $storeId'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
      
      // Remove store assignments
      for (int storeId in storesToRemove) {
        final success = await provider.removeUserFromStore(userId, storeId);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove user from store ID: $storeId'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update store assignments: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<UserManagementProvider>();
    bool success;

    if (isEditing) {
      // Update user basic information
      success = await provider.updateUser(
        id: widget.user!.id,
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        role: _selectedRole,
        isActive: _isActive,
      );
      
      // Update store assignments if user update was successful
      if (success && mounted) {
        await _updateUserStoreAssignments(provider, widget.user!.id);
      }
    } else {
      // Create user first
      final newUser = await provider.createUser(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        role: _selectedRole,
        password: _passwordController.text,
        passwordConfirm: _confirmPasswordController.text,
      );

      success = newUser != null;

      // If user creation was successful and a store is selected, assign the user to the store
      if (success && _selectedStoreId != null && mounted) {
        // Double check that both IDs are valid integers before assignment
        if (newUser?.id != null && newUser!.id > 0 && _selectedStoreId! > 0) {
          final storeAssignSuccess = await provider.assignUserToStore(newUser.id, _selectedStoreId!);
          
          if (!storeAssignSuccess && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User created but store assignment failed'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      }
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'User updated successfully' : 'User created successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}