import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/invoice_settings.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/invoice_settings_provider.dart';

/// Invoice Settings Screen
/// Allows admins to configure:
/// 1. Default Values (payment terms, tax rates, T&C)
/// 2. Layout Preferences (default PDF layout)
/// 3. Numbering Configuration (prefix, format, reset frequency)
class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasChanges = false;

  // Default Values
  int _paymentTermsDays = 30;
  double _defaultTaxRate = 18.0;
  int _invoiceValidityDays = 30;
  final TextEditingController _termsController = TextEditingController();

  // Layout Preferences
  String _defaultLayout = 'classic';
  bool _allowStoreOverride = true;

  // Numbering Configuration
  final TextEditingController _prefixController = TextEditingController(text: 'INV');
  final TextEditingController _separatorController = TextEditingController(text: '/');
  int _sequencePadding = 4;
  String _resetFrequency = 'yearly';

  @override
  void initState() {
    super.initState();

    // Set default T&C
    _termsController.text = '''1. Goods once sold will not be taken back.
2. Interest @ 18% p.a. will be charged on delayed payments.
3. Subject to jurisdiction only.
4. All disputes subject to arbitration only.''';

    // Load settings after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });

    // Listen to changes
    _termsController.addListener(() {
      setState(() {
        _hasChanges = true;
      });
    });
    _prefixController.addListener(() {
      setState(() {
        _hasChanges = true;
      });
    });
    _separatorController.addListener(() {
      setState(() {
        _hasChanges = true;
      });
    });
  }

  @override
  void dispose() {
    _termsController.dispose();
    _prefixController.dispose();
    _separatorController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = context.read<InvoiceSettingsProvider>();
      await settingsProvider.loadSettings();

      if (settingsProvider.settings != null) {
        final settings = settingsProvider.settings!;
        setState(() {
          // Default Values
          _paymentTermsDays = settings.invoiceDefaultPaymentTerms;
          _defaultTaxRate = settings.invoiceDefaultTaxRate;
          _invoiceValidityDays = settings.invoiceValidityDays;
          _termsController.text = settings.invoiceTermsAndConditions ?? '';

          // Layout Preferences
          _defaultLayout = settings.invoiceLayoutPreference;
          _allowStoreOverride = settings.allowStoreOverride;

          // Numbering Configuration
          _prefixController.text = settings.invoiceNumberPrefix;
          _separatorController.text = settings.invoiceNumberSeparator;
          _sequencePadding = settings.invoiceSequencePadding;
          _resetFrequency = settings.invoiceResetFrequency;

          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load settings: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = context.read<InvoiceSettingsProvider>();

      final settings = InvoiceSettings(
        // Layout Settings
        invoiceLayoutPreference: _defaultLayout,
        allowStoreOverride: _allowStoreOverride,
        // Default Values
        invoiceDefaultPaymentTerms: _paymentTermsDays,
        invoiceDefaultTaxRate: _defaultTaxRate,
        invoiceValidityDays: _invoiceValidityDays,
        invoiceTermsAndConditions: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        // Numbering Configuration
        invoiceNumberPrefix: _prefixController.text.trim(),
        invoiceNumberSeparator: _separatorController.text,
        invoiceSequencePadding: _sequencePadding,
        invoiceResetFrequency: _resetFrequency,
      );

      final success = await settingsProvider.saveSettings(settings);

      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Return true to indicate settings were updated
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save settings: ${settingsProvider.errorMessage ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          );

          return shouldDiscard ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Invoice Settings'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _saveSettings,
                child: Text(
                  'SAVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Default Values', Icons.settings_suggest),
                      _buildDefaultValuesSection(),
                      SizedBox(height: 24.h),
                      _buildSectionHeader('Layout Preferences', Icons.palette),
                      _buildLayoutPreferencesSection(),
                      SizedBox(height: 24.h),
                      _buildSectionHeader('Invoice Numbering', Icons.format_list_numbered),
                      _buildNumberingConfigSection(),
                      SizedBox(height: 32.h),
                      if (!_hasChanges)
                        Center(
                          child: Text(
                            'Make changes above and tap SAVE to update settings',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: _hasChanges
            ? Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultValuesSection() {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          // Payment Terms
          Text('Payment Terms', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          DropdownButtonFormField<int>(
            value: _paymentTermsDays,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today, size: 20),
              hintText: 'Select payment terms',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Due on Receipt')),
              DropdownMenuItem(value: 15, child: Text('Net 15 Days')),
              DropdownMenuItem(value: 30, child: Text('Net 30 Days')),
              DropdownMenuItem(value: 45, child: Text('Net 45 Days')),
              DropdownMenuItem(value: 60, child: Text('Net 60 Days')),
              DropdownMenuItem(value: 90, child: Text('Net 90 Days')),
            ],
            onChanged: (value) {
              setState(() {
                _paymentTermsDays = value!;
                _hasChanges = true;
              });
            },
          ),
          SizedBox(height: 16.h),

          // Default Tax Rate
          Text('Default Tax Rate (%)', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          DropdownButtonFormField<double>(
            value: _defaultTaxRate,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.percent, size: 20),
              hintText: 'Select default GST rate',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            items: const [
              DropdownMenuItem(value: 0.0, child: Text('0% (Nil Rated)')),
              DropdownMenuItem(value: 5.0, child: Text('5% GST')),
              DropdownMenuItem(value: 12.0, child: Text('12% GST')),
              DropdownMenuItem(value: 18.0, child: Text('18% GST')),
              DropdownMenuItem(value: 28.0, child: Text('28% GST')),
            ],
            onChanged: (value) {
              setState(() {
                _defaultTaxRate = value!;
                _hasChanges = true;
              });
            },
          ),
          SizedBox(height: 16.h),

          // Invoice Validity
          Text('Invoice Validity (Days)', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          DropdownButtonFormField<int>(
            value: _invoiceValidityDays,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.timer, size: 20),
              hintText: 'Select invoice validity period',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            items: const [
              DropdownMenuItem(value: 7, child: Text('7 Days')),
              DropdownMenuItem(value: 15, child: Text('15 Days')),
              DropdownMenuItem(value: 30, child: Text('30 Days')),
              DropdownMenuItem(value: 60, child: Text('60 Days')),
              DropdownMenuItem(value: 90, child: Text('90 Days')),
            ],
            onChanged: (value) {
              setState(() {
                _invoiceValidityDays = value!;
                _hasChanges = true;
              });
            },
          ),
          SizedBox(height: 16.h),

          // Terms & Conditions
          Text('Default Terms & Conditions', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          TextFormField(
            controller: _termsController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Enter default terms and conditions',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.all(12.w),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter terms and conditions';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutPreferencesSection() {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          Text('Default Invoice PDF Layout', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 12.h),

          // Layout Options
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _defaultLayout = 'classic';
                      _hasChanges = true;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _defaultLayout == 'classic' ? AppColors.primary : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                      color: _defaultLayout == 'classic' ? AppColors.primary.withOpacity(0.05) : Colors.white,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 32.sp,
                          color: _defaultLayout == 'classic' ? AppColors.primary : Colors.grey,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Classic Layout',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _defaultLayout == 'classic' ? AppColors.primary : Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Modern blue theme',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _defaultLayout = 'traditional';
                      _hasChanges = true;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _defaultLayout == 'traditional' ? AppColors.primary : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                      color: _defaultLayout == 'traditional' ? AppColors.primary.withOpacity(0.05) : Colors.white,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.description,
                          size: 32.sp,
                          color: _defaultLayout == 'traditional' ? AppColors.primary : Colors.grey,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Traditional',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _defaultLayout == 'traditional' ? AppColors.primary : Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Govt. standard',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Store Override Option
          SwitchListTile(
            title: Text('Allow Store-level Override', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text(
              'Stores can choose their own PDF layout',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
            value: _allowStoreOverride,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _allowStoreOverride = value;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNumberingConfigSection() {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          // Invoice Prefix
          Text('Invoice Number Prefix', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          TextFormField(
            controller: _prefixController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.tag, size: 20),
              hintText: 'e.g., INV, BILL, TXN',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a prefix';
              }
              if (value.length > 10) {
                return 'Prefix too long (max 10 characters)';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // Separator
          Text('Separator', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          TextFormField(
            controller: _separatorController,
            maxLength: 1,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.horizontal_rule, size: 20),
              hintText: 'e.g., /, -, _',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a separator';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // Sequence Padding
          Text('Sequence Number Padding', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          DropdownButtonFormField<int>(
            value: _sequencePadding,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.format_list_numbered, size: 20),
              hintText: 'Select padding',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            items: const [
              DropdownMenuItem(value: 3, child: Text('3 digits (001, 002, ...)')),
              DropdownMenuItem(value: 4, child: Text('4 digits (0001, 0002, ...)')),
              DropdownMenuItem(value: 5, child: Text('5 digits (00001, 00002, ...)')),
              DropdownMenuItem(value: 6, child: Text('6 digits (000001, 000002, ...)')),
            ],
            onChanged: (value) {
              setState(() {
                _sequencePadding = value!;
                _hasChanges = true;
              });
            },
          ),
          SizedBox(height: 16.h),

          // Reset Frequency
          Text('Sequence Reset Frequency', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            value: _resetFrequency,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.replay, size: 20),
              hintText: 'Select reset frequency',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            items: const [
              DropdownMenuItem(value: 'never', child: Text('Never (Continuous)')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly (Financial Year)')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            ],
            onChanged: (value) {
              setState(() {
                _resetFrequency = value!;
                _hasChanges = true;
              });
            },
          ),
          SizedBox(height: 16.h),

          // Preview
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, color: Colors.blue[700], size: 20.sp),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview:',
                      style: TextStyle(fontSize: 12.sp, color: Colors.blue[900], fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _generatePreviewNumber(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
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

  String _generatePreviewNumber() {
    final year = DateTime.now().year;
    final fy = _resetFrequency == 'yearly' ? '$year-${(year + 1).toString().substring(2)}' : '';
    final month = _resetFrequency == 'monthly' ? DateTime.now().month.toString().padLeft(2, '0') : '';
    final sequence = '1'.padLeft(_sequencePadding, '0');
    final sep = _separatorController.text.isEmpty ? '/' : _separatorController.text;

    final parts = [
      _prefixController.text.isEmpty ? 'INV' : _prefixController.text,
      if (_resetFrequency != 'never') 'S01', // Store code
      if (fy.isNotEmpty) fy,
      if (month.isNotEmpty) month,
      sequence,
    ];

    return parts.join(sep);
  }
}
