import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';

class CustomSearchBar extends StatefulWidget {
  final String hint;
  final Function(String) onChanged;
  final Function(String)? onSubmitted;
  final String? initialValue;
  final bool enabled;
  final Widget? suffixIcon;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final double? borderRadius;
  final TextInputType? keyboardType;

  const CustomSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.initialValue,
    this.enabled = true,
    this.suffixIcon,
    this.onClear,
    this.margin,
    this.padding,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.borderRadius,
    this.keyboardType,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? 30.0;
    final fillColor = widget.fillColor ?? Colors.white;
    final borderColor = widget.borderColor ?? const Color(0xFFE5E7EB);
    final focusedBorderColor = widget.focusedBorderColor ?? AppColors.primary;
    
    return Container(
      margin: widget.margin ?? EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() {});
            widget.onChanged(value);
          },
          onSubmitted: widget.onSubmitted,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: fillColor,
            
            // Prefix Icon (Search Icon)
            prefixIcon: Container(
              width: 48.w,
              height: 48.h,
              alignment: Alignment.center,
              child: Icon(
                Icons.search_rounded,
                color: _isFocused || _controller.text.isNotEmpty
                    ? focusedBorderColor
                    : const Color(0xFF64748B),
                size: 22.w,
              ),
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: 48.w,
              minHeight: 48.h,
            ),
            
            // Suffix Icon (Clear button or custom)
            suffixIcon: _controller.text.isNotEmpty
                ? Container(
                    width: 48.w,
                    height: 48.h,
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: const Color(0xFF64748B),
                        size: 18.w,
                      ),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged('');
                        if (widget.onClear != null) {
                          widget.onClear!();
                        }
                        setState(() {});
                      },
                      padding: EdgeInsets.all(8.w),
                      constraints: BoxConstraints(
                        minWidth: 32.w,
                        minHeight: 32.h,
                      ),
                    ),
                  )
                : widget.suffixIcon,
            
            // Content Padding
            contentPadding: widget.padding ?? EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 16.h,
            ),
            
            // Border Styling - Enhanced visibility
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
              borderSide: BorderSide(
                color: borderColor,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
              borderSide: BorderSide(
                color: borderColor,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
              borderSide: BorderSide(
                color: focusedBorderColor,
                width: 2.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
              borderSide: BorderSide(
                color: borderColor.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2.0,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius.r),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Simple search bar variant with minimal styling
class SimpleSearchBar extends StatelessWidget {
  final String hint;
  final Function(String) onChanged;
  final String? initialValue;
  final bool enabled;
  final EdgeInsetsGeometry? margin;

  const SimpleSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialValue,
    this.enabled = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSearchBar(
      hint: hint,
      onChanged: onChanged,
      initialValue: initialValue,
      enabled: enabled,
      margin: margin,
      borderRadius: 30.0,
      fillColor: Colors.white,
      borderColor: const Color(0xFFE5E7EB),
      focusedBorderColor: AppColors.primary,
    );
  }
}