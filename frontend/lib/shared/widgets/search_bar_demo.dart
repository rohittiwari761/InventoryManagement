import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import 'custom_search_bar.dart';

class SearchBarDemo extends StatefulWidget {
  const SearchBarDemo({super.key});

  @override
  State<SearchBarDemo> createState() => _SearchBarDemoState();
}

class _SearchBarDemoState extends State<SearchBarDemo> {
  String _searchQuery1 = '';
  String _searchQuery2 = '';
  String _searchQuery3 = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Bar Examples'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Search Bar Variants',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 24.h),
            
            // Standard Rounded Search Bar (30px radius)
            _buildSection(
              title: '1. Standard Rounded Search Bar (30px radius)',
              description: 'Perfect for modern UI with rounded corners and proper icon alignment',
              child: CustomSearchBar(
                hint: 'Search products, customers...',
                onChanged: (value) => setState(() => _searchQuery1 = value),
                borderRadius: 30.0,
                margin: EdgeInsets.symmetric(horizontal: 0),
              ),
            ),
            
            // Compact Search Bar 
            _buildSection(
              title: '2. Compact Search Bar (16px radius)',
              description: 'More compact version suitable for lists and cards',
              child: CustomSearchBar(
                hint: 'Search items...',
                onChanged: (value) => setState(() => _searchQuery2 = value),
                borderRadius: 16.0,
                margin: EdgeInsets.symmetric(horizontal: 0),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
            
            // Custom Styled Search Bar
            _buildSection(
              title: '3. Custom Styled Search Bar',
              description: 'Custom colors and styling options',
              child: CustomSearchBar(
                hint: 'Search with custom styling...',
                onChanged: (value) => setState(() => _searchQuery3 = value),
                borderRadius: 25.0,
                margin: EdgeInsets.symmetric(horizontal: 0),
                fillColor: AppColors.primary.withOpacity(0.05),
                borderColor: AppColors.primary.withOpacity(0.3),
                focusedBorderColor: AppColors.primary,
              ),
            ),
            
            // Simple Search Bar (using helper)
            _buildSection(
              title: '4. Simple Search Bar (Helper Widget)',
              description: 'Using the SimpleSearchBar for quick implementation',
              child: SimpleSearchBar(
                hint: 'Quick search...',
                onChanged: (value) => {},
                margin: EdgeInsets.symmetric(horizontal: 0),
              ),
            ),
            
            // Search Results Display
            SizedBox(height: 32.h),
            Text(
              'Search Queries:',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            _buildQueryDisplay('Query 1', _searchQuery1),
            _buildQueryDisplay('Query 2', _searchQuery2),
            _buildQueryDisplay('Query 3', _searchQuery3),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
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
        SizedBox(height: 8.h),
        Text(
          description,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 12.h),
        child,
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildQueryDisplay(String label, String query) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                query.isEmpty ? 'No query' : query,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: query.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                  fontStyle: query.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}