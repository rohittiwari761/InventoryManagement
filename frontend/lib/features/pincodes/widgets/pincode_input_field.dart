import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../services/pincode_service.dart';

class PinCodeInputField extends StatefulWidget {
  final TextEditingController pincodeController;
  final TextEditingController? cityController;
  final TextEditingController? stateController;
  final TextEditingController? districtController;
  final String? label;
  final String? hint;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(Map<String, dynamic>)? onPinCodeFound;
  final void Function(String)? onPinCodeNotFound;
  final bool autoFillCityState;

  const PinCodeInputField({
    super.key,
    required this.pincodeController,
    this.cityController,
    this.stateController,
    this.districtController,
    this.label = 'PIN Code',
    this.hint = 'Enter 6-digit PIN code',
    this.enabled = true,
    this.validator,
    this.onPinCodeFound,
    this.onPinCodeNotFound,
    this.autoFillCityState = true,
  });

  @override
  State<PinCodeInputField> createState() => _PinCodeInputFieldState();
}

class _PinCodeInputFieldState extends State<PinCodeInputField> {
  final PinCodeService _pinCodeService = PinCodeService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.pincodeController.addListener(_onPinCodeChanged);
  }

  @override
  void dispose() {
    widget.pincodeController.removeListener(_onPinCodeChanged);
    super.dispose();
  }

  void _onPinCodeChanged() {
    final pincode = widget.pincodeController.text.trim();
    
    // Clear previous error
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
    
    // Auto-lookup when PIN code is 6 digits
    if (pincode.length == 6 && RegExp(r'^\d{6}$').hasMatch(pincode)) {
      _lookupPinCode(pincode);
    } else if (pincode.length > 6) {
      // Clear city/state if PIN code becomes invalid
      _clearLocationFields();
    }
  }

  Future<void> _lookupPinCode(String pincode) async {
    if (!widget.autoFillCityState) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pinCodeData = await _pinCodeService.lookupPinCode(pincode);
      
      if (pinCodeData != null && mounted) {
        // Auto-fill the city and state fields
        if (widget.cityController != null) {
          widget.cityController!.text = pinCodeData['city'] ?? '';
        }
        if (widget.stateController != null) {
          widget.stateController!.text = pinCodeData['state'] ?? '';
        }
        if (widget.districtController != null) {
          widget.districtController!.text = pinCodeData['district'] ?? '';
        }
        
        // Callback for additional handling
        widget.onPinCodeFound?.call(pinCodeData);
        
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Don't show error message for PIN code not found
        // Just silently fail and let user proceed with manual entry
        setState(() {
          _isLoading = false;
        });
        
        // Only call the callback, don't clear fields or show error
        widget.onPinCodeNotFound?.call(pincode);
      }
    }
  }

  void _clearLocationFields() {
    if (widget.autoFillCityState) {
      widget.cityController?.clear();
      widget.stateController?.clear();
      widget.districtController?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.pincodeController,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _isLoading
                ? Padding(
                    padding: EdgeInsets.all(12.w),
                    child: SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.pincodeController.text.length == 6 &&
                        RegExp(r'^\d{6}$').hasMatch(widget.pincodeController.text)
                    ? Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20.w,
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: _errorMessage != null ? AppColors.error : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: _errorMessage != null ? AppColors.error : AppColors.primary,
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
            counterText: '',
          ),
          validator: widget.validator ?? _defaultValidator,
        ),
        if (_errorMessage != null) ...[
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 16.w,
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PIN code is required';
    }
    if (value.trim().length != 6) {
      return 'PIN code must be 6 digits';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'PIN code must contain only digits';
    }
    return null;
  }
}