import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../shared/models/invoice.dart';

/// Service for exporting invoice data to CSV format
/// Generates CSV files that can be opened in Excel, Google Sheets, etc.
class ExportService {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');

  /// Export invoices to CSV file
  /// Returns the file path of the generated CSV file
  Future<String> exportToCSV({
    required List<Invoice> invoices,
    required String financialYear,
    String? startDate,
    String? endDate,
  }) async {
    // Generate CSV data
    final List<List<dynamic>> csvData = [];

    // Add header section
    csvData.add(['INVOICE EXPORT']);
    csvData.add(['Financial Year:', financialYear]);
    if (startDate != null && endDate != null) {
      csvData.add(['Period:', '$startDate to $endDate']);
    }
    csvData.add(['Generated On:', _dateFormat.format(DateTime.now())]);
    csvData.add([]); // Empty row

    // Calculate statistics
    final totalInvoices = invoices.length;
    final totalAmount = invoices.fold<double>(0, (sum, inv) => sum + inv.totalAmount);
    final totalTax = invoices.fold<double>(0, (sum, inv) => sum + inv.totalTaxAmount);
    final totalCGST = invoices.fold<double>(0, (sum, inv) => sum + inv.cgstAmount);
    final totalSGST = invoices.fold<double>(0, (sum, inv) => sum + inv.sgstAmount);
    final totalIGST = invoices.fold<double>(0, (sum, inv) => sum + inv.igstAmount);

    // Status breakdown
    final draftCount = invoices.where((i) => i.status == InvoiceStatus.draft).length;
    final sentCount = invoices.where((i) => i.status == InvoiceStatus.sent).length;
    final paidCount = invoices.where((i) => i.status == InvoiceStatus.paid).length;
    final cancelledCount = invoices.where((i) => i.status == InvoiceStatus.cancelled).length;
    final overdueCount = invoices.where((i) => i.status == InvoiceStatus.overdue).length;

    // Add summary section
    csvData.add(['OVERALL STATISTICS']);
    csvData.add(['Total Invoices:', totalInvoices]);
    csvData.add(['Total Amount:', _currencyFormat.format(totalAmount)]);
    csvData.add(['Total Tax Collected:', _currencyFormat.format(totalTax)]);
    csvData.add([]); // Empty row

    csvData.add(['TAX BREAKDOWN']);
    csvData.add(['Total CGST:', _currencyFormat.format(totalCGST)]);
    csvData.add(['Total SGST:', _currencyFormat.format(totalSGST)]);
    csvData.add(['Total IGST:', _currencyFormat.format(totalIGST)]);
    csvData.add([]); // Empty row

    csvData.add(['STATUS BREAKDOWN']);
    csvData.add(['Draft:', draftCount]);
    csvData.add(['Sent:', sentCount]);
    csvData.add(['Paid:', paidCount]);
    csvData.add(['Overdue:', overdueCount]);
    csvData.add(['Cancelled:', cancelledCount]);
    csvData.add([]); // Empty row
    csvData.add([]); // Empty row

    // Add invoice details section
    csvData.add(['INVOICE DETAILS']);
    csvData.add([
      'Invoice No',
      'Date',
      'Due Date',
      'Customer Name',
      'Customer GSTIN',
      'Customer State',
      'Place of Supply',
      'Invoice Type',
      'Is Inter-State',
      'Subtotal',
      'CGST',
      'SGST',
      'IGST',
      'Total Tax',
      'Total Amount',
      'Status',
      'Financial Year',
    ]);

    // Add invoice data
    for (final invoice in invoices) {
      csvData.add([
        invoice.invoiceNumber,
        _dateFormat.format(invoice.invoiceDate),
        invoice.dueDate != null ? _dateFormat.format(invoice.dueDate!) : 'N/A',
        invoice.customerName,
        invoice.customerGstin ?? 'N/A',
        invoice.customerState ?? '',
        invoice.placeOfSupply ?? 'N/A',
        invoice.invoiceType,
        invoice.isInterState ? 'Yes' : 'No',
        invoice.subtotal.toStringAsFixed(2),
        invoice.cgstAmount.toStringAsFixed(2),
        invoice.sgstAmount.toStringAsFixed(2),
        invoice.igstAmount.toStringAsFixed(2),
        invoice.totalTaxAmount.toStringAsFixed(2),
        invoice.totalAmount.toStringAsFixed(2),
        _getStatusText(invoice.status),
        invoice.financialYear,
      ]);
    }

    // Convert to CSV string
    final String csvString = const ListToCsvConverter().convert(csvData);

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'Invoice_Export_${financialYear.replaceAll('-', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(csvString);

    return filePath;
  }

  /// Get status display text
  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.overdue:
        return 'Overdue';
    }
  }
}
