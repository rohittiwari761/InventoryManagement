import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Financial Year Selector Dropdown
/// Generates list of financial years (April-March) for selection
class FYSelectorDropdown extends StatelessWidget {
  final String? selectedFY;
  final ValueChanged<String?> onChanged;
  final int yearsBack;
  final int yearsForward;

  const FYSelectorDropdown({
    super.key,
    this.selectedFY,
    required this.onChanged,
    this.yearsBack = 5,
    this.yearsForward = 1,
  });

  /// Generate list of financial years
  List<String> _generateFinancialYears() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // If current month is Jan-Mar, we're in previous FY
    // If current month is Apr-Dec, we're in current FY
    final currentFYStartYear = currentMonth >= 4 ? currentYear : currentYear - 1;

    final years = <String>[];
    for (int i = -yearsBack; i <= yearsForward; i++) {
      final startYear = currentFYStartYear + i;
      final endYear = startYear + 1;
      years.add('$startYear-${endYear.toString().substring(2)}');
    }

    return years.reversed.toList(); // Most recent first
  }

  /// Get display text for FY
  String _getFYDisplayText(String fy) {
    final parts = fy.split('-');
    if (parts.length == 2) {
      return 'FY ${parts[0]}-${parts[1]}';
    }
    return fy;
  }

  @override
  Widget build(BuildContext context) {
    final fyList = _generateFinancialYears();
    final currentFY = selectedFY ?? fyList.first;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentFY,
          icon: Icon(Icons.calendar_today, size: 18.sp, color: Colors.blue),
          isExpanded: true,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          items: fyList.map((fy) {
            return DropdownMenuItem<String>(
              value: fy,
              child: Row(
                children: [
                  Icon(
                    Icons.event_note,
                    size: 16.sp,
                    color: fy == currentFY ? Colors.blue : Colors.grey,
                  ),
                  SizedBox(width: 8.w),
                  Text(_getFYDisplayText(fy)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Financial Year Range Picker Dialog
/// Shows a dialog to select FY or custom date range
class FYRangePickerDialog extends StatefulWidget {
  final String? initialFY;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const FYRangePickerDialog({
    super.key,
    this.initialFY,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<FYRangePickerDialog> createState() => _FYRangePickerDialogState();

  /// Show the dialog and return the selected range
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    String? initialFY,
    DateTime? initialStartDate,
    DateTime? initialEndDate,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FYRangePickerDialog(
        initialFY: initialFY,
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }
}

class _FYRangePickerDialogState extends State<FYRangePickerDialog> {
  String? selectedFY;
  bool useCustomRange = false;
  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  void initState() {
    super.initState();
    selectedFY = widget.initialFY;
    customStartDate = widget.initialStartDate;
    customEndDate = widget.initialEndDate;
    useCustomRange = customStartDate != null && customEndDate != null;
  }

  /// Parse FY string to get start and end dates
  Map<String, DateTime> _parseFY(String fy) {
    final parts = fy.split('-');
    final startYear = int.parse(parts[0]);
    final startDate = DateTime(startYear, 4, 1); // April 1st
    final endDate = DateTime(startYear + 1, 3, 31); // March 31st

    return {
      'start': startDate,
      'end': endDate,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        padding: EdgeInsets.all(20.w),
        constraints: BoxConstraints(maxWidth: 400.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.date_range, color: Colors.blue, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'Select Period',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Financial Year Option
            RadioListTile<bool>(
              title: const Text('Financial Year'),
              value: false,
              groupValue: useCustomRange,
              onChanged: (value) {
                setState(() {
                  useCustomRange = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (!useCustomRange) ...[
              SizedBox(height: 12.h),
              FYSelectorDropdown(
                selectedFY: selectedFY,
                onChanged: (fy) {
                  setState(() {
                    selectedFY = fy;
                  });
                },
              ),
            ],

            SizedBox(height: 16.h),

            // Custom Range Option
            RadioListTile<bool>(
              title: const Text('Custom Date Range'),
              value: true,
              groupValue: useCustomRange,
              onChanged: (value) {
                setState(() {
                  useCustomRange = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (useCustomRange) ...[
              SizedBox(height: 12.h),
              _buildDateRangePicker(),
            ],

            SizedBox(height: 24.h),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                SizedBox(width: 12.w),
                ElevatedButton(
                  onPressed: _onConfirm,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      children: [
        // Start Date
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today, color: Colors.blue),
          title: const Text('Start Date'),
          subtitle: Text(
            customStartDate != null
                ? '${customStartDate!.day}/${customStartDate!.month}/${customStartDate!.year}'
                : 'Not selected',
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: customStartDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                customStartDate = date;
              });
            }
          },
        ),

        // End Date
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event, color: Colors.blue),
          title: const Text('End Date'),
          subtitle: Text(
            customEndDate != null
                ? '${customEndDate!.day}/${customEndDate!.month}/${customEndDate!.year}'
                : 'Not selected',
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: customEndDate ?? DateTime.now(),
              firstDate: customStartDate ?? DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                customEndDate = date;
              });
            }
          },
        ),
      ],
    );
  }

  void _onConfirm() {
    if (useCustomRange) {
      if (customStartDate == null || customEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both start and end dates')),
        );
        return;
      }

      Navigator.pop(context, {
        'type': 'custom',
        'startDate': customStartDate,
        'endDate': customEndDate,
      });
    } else {
      if (selectedFY == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a financial year')),
        );
        return;
      }

      final dates = _parseFY(selectedFY!);
      Navigator.pop(context, {
        'type': 'fy',
        'fy': selectedFY,
        'startDate': dates['start'],
        'endDate': dates['end'],
      });
    }
  }
}
