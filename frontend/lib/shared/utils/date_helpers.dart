/// Date helper utilities for financial year calculations
/// Indian financial year runs from April 1 to March 31

/// Calculate Indian financial year from a given date
/// Financial year runs from April 1 to March 31
///
/// Examples:
/// - March 31, 2025 -> "2024-25"
/// - April 1, 2025 -> "2025-26"
/// - January 15, 2025 -> "2024-25"
/// - December 20, 2024 -> "2024-25"
String getFinancialYear(DateTime date) {
  if (date.month >= 4) {
    // April to December: FY is current_year to next_year
    final nextYear = date.year + 1;
    return '${date.year}-${nextYear.toString().substring(2)}';
  } else {
    // January to March: FY is previous_year to current_year
    final prevYear = date.year - 1;
    return '$prevYear-${date.year.toString().substring(2)}';
  }
}

/// Get FY start and end dates for a given date
///
/// Returns a record (fyStart, fyEnd) with the financial year boundaries
///
/// Examples:
/// - March 31, 2025 -> (DateTime(2024, 4, 1), DateTime(2025, 3, 31, 23, 59, 59))
/// - April 1, 2025 -> (DateTime(2025, 4, 1), DateTime(2026, 3, 31, 23, 59, 59))
/// - January 15, 2025 -> (DateTime(2024, 4, 1), DateTime(2025, 3, 31, 23, 59, 59))
(DateTime, DateTime) getFinancialYearRange(DateTime date) {
  DateTime fyStart;
  DateTime fyEnd;

  if (date.month >= 4) {
    // April to December: FY is current_year to next_year
    fyStart = DateTime(date.year, 4, 1);
    fyEnd = DateTime(date.year + 1, 3, 31, 23, 59, 59);
  } else {
    // January to March: FY is previous_year to current_year
    fyStart = DateTime(date.year - 1, 4, 1);
    fyEnd = DateTime(date.year, 3, 31, 23, 59, 59);
  }

  return (fyStart, fyEnd);
}

/// Get the financial year for the current date
String getCurrentFinancialYear() {
  return getFinancialYear(DateTime.now());
}

/// Check if a date falls within a specific financial year
bool isInFinancialYear(DateTime date, String financialYear) {
  return getFinancialYear(date) == financialYear;
}

/// Get start year from financial year string
/// Example: "2024-25" -> 2024
int getFYStartYear(String financialYear) {
  return int.parse(financialYear.split('-')[0]);
}

/// Get end year from financial year string
/// Example: "2024-25" -> 2025
int getFYEndYear(String financialYear) {
  final startYear = getFYStartYear(financialYear);
  return startYear + 1;
}
