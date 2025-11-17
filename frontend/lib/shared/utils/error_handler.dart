import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';

class AppError {
  final String type;
  final String userMessage;
  final String? suggestion;
  final Map<String, dynamic>? details;

  AppError({
    required this.type,
    required this.userMessage,
    this.suggestion,
    this.details,
  });
}

class ErrorHandler {
  static AppError parseError(dynamic error) {
    final errorString = error.toString();
    
    // Try to parse structured error from backend
    if (errorString.contains('"type":') && errorString.contains('"user_message":')) {
      try {
        // Extract JSON from error string
        final jsonStart = errorString.indexOf('{');
        final jsonEnd = errorString.lastIndexOf('}') + 1;
        
        if (jsonStart != -1 && jsonEnd > jsonStart) {
          final jsonString = errorString.substring(jsonStart, jsonEnd);
          final errorData = jsonDecode(jsonString);
          
          return AppError(
            type: errorData['type'] ?? 'unknown',
            userMessage: errorData['user_message'] ?? 'An error occurred',
            suggestion: errorData['suggestion'],
            details: errorData,
          );
        }
      } catch (e) {
        // If JSON parsing fails, fall through to generic handling
      }
    }
    
    // Handle specific error patterns
    if (errorString.contains('Insufficient inventory')) {
      return _parseInventoryError(errorString);
    }
    
    if (errorString.contains('Invalid credentials') || errorString.contains('Authentication')) {
      return AppError(
        type: 'authentication',
        userMessage: 'Invalid login credentials',
        suggestion: 'Please check your email and password and try again.',
      );
    }
    
    if (errorString.contains('Network') || errorString.contains('Connection')) {
      return AppError(
        type: 'network',
        userMessage: 'Connection problem',
        suggestion: 'Please check your internet connection and try again.',
      );
    }
    
    if (errorString.contains('Permission denied') || errorString.contains('Unauthorized')) {
      return AppError(
        type: 'permission',
        userMessage: 'Access denied',
        suggestion: 'You don\'t have permission to perform this action.',
      );
    }
    
    // Generic error fallback
    return AppError(
      type: 'generic',
      userMessage: 'Something went wrong',
      suggestion: 'Please try again. If the problem persists, contact support.',
    );
  }
  
  static AppError _parseInventoryError(String errorString) {
    // Extract item name from old format if present
    String itemName = 'item';
    final itemMatch = RegExp(r"Insufficient inventory for '([^']+)'").firstMatch(errorString);
    if (itemMatch != null) {
      itemName = itemMatch.group(1) ?? 'item';
    }
    
    // Extract quantities if present
    String availableQty = '';
    String requestedQty = '';
    
    final availableMatch = RegExp(r'Available: ([0-9.]+)').firstMatch(errorString);
    final requestedMatch = RegExp(r'Requested: ([0-9.]+)').firstMatch(errorString);
    
    if (availableMatch != null && requestedMatch != null) {
      availableQty = availableMatch.group(1) ?? '';
      requestedQty = requestedMatch.group(1) ?? '';
    }
    
    String suggestion = 'Please reduce the quantity or restock inventory.';
    if (availableQty.isNotEmpty) {
      suggestion = 'Only $availableQty units available. Please reduce quantity or restock inventory.';
    }
    
    return AppError(
      type: 'insufficient_inventory',
      userMessage: 'Insufficient stock for $itemName',
      suggestion: suggestion,
      details: {
        'item_name': itemName,
        'available_quantity': availableQty,
        'requested_quantity': requestedQty,
      },
    );
  }
  
  static void showErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      builder: (context) => InventoryErrorDialog(error: error),
    );
  }
  
  static void showErrorSnackBar(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.userMessage,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (error.suggestion != null) ...[
              SizedBox(height: 4.h),
              Text(
                error.suggestion!,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        duration: Duration(seconds: error.type == 'insufficient_inventory' ? 6 : 4),
        action: error.type == 'insufficient_inventory' 
          ? SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () => showErrorDialog(context, error),
            )
          : null,
      ),
    );
  }
  
  static Color _getErrorColor(String errorType) {
    switch (errorType) {
      case 'insufficient_inventory':
        return const Color(0xFFEF4444); // Red for inventory issues
      case 'network':
        return const Color(0xFFF59E0B); // Orange for network issues
      case 'authentication':
        return const Color(0xFFDC2626); // Dark red for auth issues
      case 'permission':
        return const Color(0xFF7C2D12); // Brown for permission issues
      default:
        return const Color(0xFF6B7280); // Gray for generic errors
    }
  }
}

class InventoryErrorDialog extends StatelessWidget {
  final AppError error;
  
  const InventoryErrorDialog({super.key, required this.error});
  
  @override
  Widget build(BuildContext context) {
    final details = error.details;
    final isInventoryError = error.type == 'insufficient_inventory';
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: isInventoryError ? const Color(0xFFFEF2F2) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Icon(
              isInventoryError ? Icons.inventory_2_outlined : Icons.error_outline,
              color: isInventoryError ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
              size: 24.w,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isInventoryError ? 'Stock Issue' : 'Error',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  error.userMessage,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isInventoryError && details != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock Details',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildDetailRow('Item', details['item_name']?.toString() ?? 'Unknown'),
                  if (details['available_quantity'] != null)
                    _buildDetailRow('Available', '${details['available_quantity']} units'),
                  if (details['requested_quantity'] != null)
                    _buildDetailRow('Requested', '${details['requested_quantity']} units'),
                  if (details['shortage'] != null)
                    _buildDetailRow('Shortage', '${details['shortage']} units', isHighlight: true),
                ],
              ),
            ),
            SizedBox(height: 16.h),
          ],
          
          if (error.suggestion != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16.w,
                  color: const Color(0xFF059669),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    error.suggestion!,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF374151),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Got it',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              color: isHighlight ? const Color(0xFFEF4444) : const Color(0xFF111827),
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}