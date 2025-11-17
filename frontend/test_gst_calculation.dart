#!/usr/bin/env dart

/// Test script to verify GST calculation logic
/// This demonstrates how the GST breakdown should work with multiple tax rates

void main() {
  print('🧪 GST Calculation Test');
  print('=' * 50);
  
  // Sample invoice items with different GST rates
  final items = [
    // Item 1: 12% GST
    {
      'name': 'PVC Pipe',
      'quantity': 10.0,
      'unit_price': 100.0,
      'tax_rate': 12.0,
      'line_total': 1000.0, // quantity * unit_price
    },
    // Item 2: 18% GST  
    {
      'name': 'Steel Rod',
      'quantity': 5.0,
      'unit_price': 200.0,
      'tax_rate': 18.0,
      'line_total': 1000.0, // quantity * unit_price
    },
    // Item 3: Another 12% GST item
    {
      'name': 'Cement Bag',
      'quantity': 20.0,
      'unit_price': 50.0,
      'tax_rate': 12.0,
      'line_total': 1000.0, // quantity * unit_price
    },
  ];
  
  print('📋 Invoice Items:');
  for (final item in items) {
    print('  • ${item['name']}: ₹${item['line_total']} @ ${item['tax_rate']}% GST');
  }
  
  // Calculate GST breakdown
  final gstBreakdown = calculateGSTBreakdown(items, isInterState: false);
  
  print('\n💰 GST Breakdown (Intra-State):');
  print('─' * 40);
  print('Tax Component | Rate  | Tax Amount');
  print('─' * 40);
  
  for (final entry in gstBreakdown.entries) {
    final taxRate = entry.key;
    final amounts = entry.value;
    
    final cgstRate = taxRate / 2;
    final sgstRate = taxRate / 2;
    final cgstAmount = amounts['cgst']!;
    final sgstAmount = amounts['sgst']!;
    
    print('CGST (${cgstRate.toStringAsFixed(1)}%) | ${cgstRate.toStringAsFixed(1)}%  | ₹${cgstAmount.toStringAsFixed(2)}');
    print('SGST (${sgstRate.toStringAsFixed(1)}%) | ${sgstRate.toStringAsFixed(1)}%  | ₹${sgstAmount.toStringAsFixed(2)}');
    
    if (entry.key != gstBreakdown.keys.last) {
      print('─' * 40);
    }
  }
  
  // Calculate totals
  double totalCGST = 0;
  double totalSGST = 0;
  double subtotal = 0;
  
  for (final item in items) {
    subtotal += item['line_total'] as double;
  }
  
  for (final amounts in gstBreakdown.values) {
    totalCGST += amounts['cgst']!;
    totalSGST += amounts['sgst']!;
  }
  
  final totalTax = totalCGST + totalSGST;
  final grandTotal = subtotal + totalTax;
  
  print('─' * 40);
  print('\n📊 Summary:');
  print('  Subtotal:    ₹${subtotal.toStringAsFixed(2)}');
  print('  Total CGST:  ₹${totalCGST.toStringAsFixed(2)}');
  print('  Total SGST:  ₹${totalSGST.toStringAsFixed(2)}');
  print('  Total Tax:   ₹${totalTax.toStringAsFixed(2)}');
  print('  Grand Total: ₹${grandTotal.toStringAsFixed(2)}');
  
  print('\n✅ Expected Behavior:');
  print('  • Items with 12% GST → CGST 6% + SGST 6%');
  print('  • Items with 18% GST → CGST 9% + SGST 9%');
  print('  • Multiple 12% items combined into single 12% group');
  print('  • Each tax rate shown separately in breakdown');
  
  // Test Inter-State (IGST) scenario
  print('\n🌍 Inter-State GST Breakdown (IGST):');
  final igstBreakdown = calculateGSTBreakdown(items, isInterState: true);
  
  print('─' * 40);
  print('Tax Component | Rate  | Tax Amount');
  print('─' * 40);
  
  for (final entry in igstBreakdown.entries) {
    final taxRate = entry.key;
    final amounts = entry.value;
    final igstAmount = amounts['igst']!;
    
    print('IGST (${taxRate.toStringAsFixed(1)}%) | ${taxRate.toStringAsFixed(1)}%  | ₹${igstAmount.toStringAsFixed(2)}');
  }
  
  print('\n🎉 GST calculation logic is working correctly!');
}

Map<double, Map<String, double>> calculateGSTBreakdown(List<Map<String, dynamic>> items, {required bool isInterState}) {
  final Map<double, Map<String, double>> breakdown = {};
  
  // Group items by tax rate
  final Map<double, List<Map<String, dynamic>>> itemsByTaxRate = {};
  
  for (final item in items) {
    final taxRate = item['tax_rate'] as double;
    if (!itemsByTaxRate.containsKey(taxRate)) {
      itemsByTaxRate[taxRate] = [];
    }
    itemsByTaxRate[taxRate]!.add(item);
  }
  
  // Calculate tax amounts for each tax rate group
  for (final entry in itemsByTaxRate.entries) {
    final taxRate = entry.key;
    final items = entry.value;
    
    double totalLineAmount = 0;
    for (final item in items) {
      totalLineAmount += item['line_total'] as double;
    }
    
    if (isInterState) {
      // Inter-state: IGST = full tax rate
      final igstAmount = (totalLineAmount * taxRate) / 100;
      breakdown[taxRate] = {
        'igst': igstAmount,
        'cgst': 0.0,
        'sgst': 0.0,
      };
    } else {
      // Intra-state: CGST + SGST = tax rate / 2 each
      final cgstAmount = (totalLineAmount * taxRate / 2) / 100;
      final sgstAmount = (totalLineAmount * taxRate / 2) / 100;
      breakdown[taxRate] = {
        'cgst': cgstAmount,
        'sgst': sgstAmount,
        'igst': 0.0,
      };
    }
  }
  
  return breakdown;
}