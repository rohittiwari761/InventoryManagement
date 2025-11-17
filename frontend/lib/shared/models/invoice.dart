import 'customer.dart';

class Invoice {
  final int id;
  final String invoiceNumber;
  final int store;
  final String? storeName;
  final String? storeAddress;
  final String? storeGstin;
  final String creatorLayoutPreference;
  final int company;
  final String? companyName;
  final String? companyAddress;
  final String? companyCity;
  final String? companyState;
  final String? companyPincode;
  final String? companyPhone;
  final String? companyEmail;
  final String? companyGstin;
  final String? companyPan;
  final String? companyStateCode;
  final String? companyBankName;
  final String? companyBankAccountNumber;
  final String? companyBankIfsc;
  final String? companyBankBranch;
  final int createdBy;
  final String? createdByName;
  final int customer; // Foreign key to Customer model
  final String customerName;
  final String? customerAddress;
  final String? customerCity;
  final String? customerState;
  final String? customerPincode;
  final String? customerGstin;
  final String? customerPhone;
  final String? customerEmail;
  // Billing address (invoice-specific, overrides customer address if set)
  final String? billingAddress;
  final String? billingCity;
  final String? billingState;
  final String? billingPincode;
  // Transport/Logistics Details (Optional)
  final bool includeLogistics;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleNumber;
  final String? transportCompany;
  final String? lrNumber;
  final DateTime? dispatchDate;
  final List<InvoiceItem> items;
  final double subtotal;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTaxAmount;
  final double totalAmount;
  final double cessAmount;
  final double tcsAmount;
  final double roundOff;
  final String placeOfSupply;
  final String reverseCharge;
  final String invoiceType;
  final String termsAndConditions;
  final String? amountInWords;
  final String? notes;
  final InvoiceStatus status;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isInterState;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.store,
    this.storeName,
    this.storeAddress,
    this.storeGstin,
    this.creatorLayoutPreference = 'classic',
    required this.company,
    this.companyName,
    this.companyAddress,
    this.companyCity,
    this.companyState,
    this.companyPincode,
    this.companyPhone,
    this.companyEmail,
    this.companyGstin,
    this.companyPan,
    this.companyStateCode,
    this.companyBankName,
    this.companyBankAccountNumber,
    this.companyBankIfsc,
    this.companyBankBranch,
    required this.createdBy,
    this.createdByName,
    required this.customer,
    required this.customerName,
    this.customerAddress,
    this.customerCity,
    this.customerState,
    this.customerPincode,
    this.customerGstin,
    this.customerPhone,
    this.customerEmail,
    this.billingAddress,
    this.billingCity,
    this.billingState,
    this.billingPincode,
    this.includeLogistics = false,
    this.driverName,
    this.driverPhone,
    this.vehicleNumber,
    this.transportCompany,
    this.lrNumber,
    this.dispatchDate,
    required this.items,
    required this.subtotal,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTaxAmount,
    required this.totalAmount,
    this.cessAmount = 0.0,
    this.tcsAmount = 0.0,
    this.roundOff = 0.0,
    this.placeOfSupply = '',
    this.reverseCharge = 'No',
    this.invoiceType = 'tax_invoice',
    this.termsAndConditions = '',
    this.amountInWords,
    this.notes,
    required this.status,
    required this.invoiceDate,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.isInterState,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final invoice = Invoice(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      invoiceNumber: json['invoice_number'] ?? '',
      store: json['store'] is int ? json['store'] : (json['store'] != null ? int.parse(json['store'].toString()) : 0),
      storeName: json['store_name'],
      storeAddress: json['store_address'],
      storeGstin: json['store_gstin'],
      creatorLayoutPreference: json['creator_layout_preference'] ?? 'classic',
      company: json['company'] is int ? json['company'] : (json['company'] != null ? int.parse(json['company'].toString()) : 0),
      companyName: json['company_name'],
      companyAddress: json['company_address'],
      companyCity: json['company_city'],
      companyState: json['company_state'],
      companyPincode: json['company_pincode'],
      companyPhone: json['company_phone'],
      companyEmail: json['company_email'],
      companyGstin: json['company_gstin'],
      companyPan: json['company_pan'],
      companyStateCode: json['company_state_code'],
      companyBankName: json['company_bank_name'],
      companyBankAccountNumber: json['company_bank_account_number'],
      companyBankIfsc: json['company_bank_ifsc'],
      companyBankBranch: json['company_bank_branch'],
      createdBy: json['created_by'] is int ? json['created_by'] : (json['created_by'] != null ? int.parse(json['created_by'].toString()) : 0),
      createdByName: json['created_by_name'],
      customer: json['customer'] is int ? json['customer'] : (json['customer'] != null ? int.parse(json['customer'].toString()) : 0),
      customerName: json['customer_name'] ?? '',
      customerAddress: json['customer_address'] ?? json['customer_details']?['address'],
      customerCity: json['customer_city'] ?? json['customer_details']?['city'],
      customerState: json['customer_state'] ?? json['customer_details']?['state'],
      customerPincode: json['customer_pincode'] ?? json['customer_details']?['pincode'],
      customerGstin: json['customer_gstin'] ?? json['customer_details']?['gstin'],
      customerPhone: json['customer_phone'] ?? json['customer_details']?['phone'],
      customerEmail: json['customer_email'] ?? json['customer_details']?['email'],
      billingAddress: json['billing_address'],
      billingCity: json['billing_city'],
      billingState: json['billing_state'],
      billingPincode: json['billing_pincode'],
      includeLogistics: json['include_logistics'] ?? false,
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      vehicleNumber: json['vehicle_number'],
      transportCompany: json['transport_company'],
      lrNumber: json['lr_number'],
      dispatchDate: json['dispatch_date'] != null ? DateTime.parse(json['dispatch_date']) : null,
      items: (json['items'] as List<dynamic>?)?.map((item) => InvoiceItem.fromJson(item)).toList() ?? [],
      subtotal: json['subtotal'] != null ? double.parse(json['subtotal'].toString()) : 0.0,
      cgstAmount: json['cgst_amount'] != null ? double.parse(json['cgst_amount'].toString()) : 0.0,
      sgstAmount: json['sgst_amount'] != null ? double.parse(json['sgst_amount'].toString()) : 0.0,
      igstAmount: json['igst_amount'] != null ? double.parse(json['igst_amount'].toString()) : 0.0,
      totalTaxAmount: json['total_tax'] != null ? double.parse(json['total_tax'].toString()) : 0.0,
      totalAmount: json['total_amount'] != null ? double.parse(json['total_amount'].toString()) : 0.0,
      cessAmount: json['cess_amount'] != null ? double.parse(json['cess_amount'].toString()) : 0.0,
      tcsAmount: json['tcs_amount'] != null ? double.parse(json['tcs_amount'].toString()) : 0.0,
      roundOff: json['round_off'] != null ? double.parse(json['round_off'].toString()) : 0.0,
      placeOfSupply: json['place_of_supply'] ?? '',
      reverseCharge: json['reverse_charge'] ?? 'No',
      invoiceType: json['invoice_type'] ?? 'tax_invoice',
      termsAndConditions: json['terms_and_conditions'] ?? '',
      amountInWords: json['amount_in_words'],
      notes: json['notes'],
      status: InvoiceStatus.fromString(json['status'] ?? 'draft'),
      invoiceDate: DateTime.parse(json['invoice_date']),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      isInterState: json['is_inter_state'] ?? false,
    );

    return invoice;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'store': store,
      'store_name': storeName,
      'store_address': storeAddress,
      'store_gstin': storeGstin,
      'creator_layout_preference': creatorLayoutPreference,
      'company': company,
      'company_name': companyName,
      'company_address': companyAddress,
      'company_city': companyCity,
      'company_state': companyState,
      'company_pincode': companyPincode,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'company_gstin': companyGstin,
      'company_pan': companyPan,
      'company_state_code': companyStateCode,
      'company_bank_name': companyBankName,
      'company_bank_account_number': companyBankAccountNumber,
      'company_bank_ifsc': companyBankIfsc,
      'company_bank_branch': companyBankBranch,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'customer': customer,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'customer_city': customerCity,
      'customer_state': customerState,
      'customer_pincode': customerPincode,
      'customer_gstin': customerGstin,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'billing_address': billingAddress,
      'billing_city': billingCity,
      'billing_state': billingState,
      'billing_pincode': billingPincode,
      'include_logistics': includeLogistics,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'vehicle_number': vehicleNumber,
      'transport_company': transportCompany,
      'lr_number': lrNumber,
      'dispatch_date': dispatchDate?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
      'total_tax': totalTaxAmount,
      'total_amount': totalAmount,
      'cess_amount': cessAmount,
      'tcs_amount': tcsAmount,
      'round_off': roundOff,
      'place_of_supply': placeOfSupply,
      'reverse_charge': reverseCharge,
      'invoice_type': invoiceType,
      'terms_and_conditions': termsAndConditions,
      'amount_in_words': amountInWords,
      'notes': notes,
      'status': status.value,
      'invoice_date': invoiceDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_inter_state': isInterState,
    };
  }

  // GST type based on inter-state flag from backend
  String get gstType => isInterState ? 'IGST' : 'CGST + SGST';

  // Check if invoice has any tax amounts (for conditional UI display)
  bool get hasTaxes => cgstAmount > 0 || sgstAmount > 0 || igstAmount > 0;

  // Financial year getter (April-March)
  String get financialYear {
    // Import is at top of file, so we can use the helper function directly
    // Calculate from invoice date
    if (invoiceDate.month >= 4) {
      // April to December: FY is current_year to next_year
      final nextYear = invoiceDate.year + 1;
      return '${invoiceDate.year}-${nextYear.toString().substring(2)}';
    } else {
      // January to March: FY is previous_year to current_year
      final prevYear = invoiceDate.year - 1;
      return '$prevYear-${invoiceDate.year.toString().substring(2)}';
    }
  }

  String get formattedInvoiceDate => '${invoiceDate.day.toString().padLeft(2, '0')}/${invoiceDate.month.toString().padLeft(2, '0')}/${invoiceDate.year}';

  String get formattedDueDate => dueDate != null
      ? '${dueDate!.day.toString().padLeft(2, '0')}/${dueDate!.month.toString().padLeft(2, '0')}/${dueDate!.year}'
      : '';
  
  String get formattedCustomerAddress {
    final addressParts = <String>[];

    // Use billing address if set, otherwise use customer default address
    final address = (billingAddress?.isNotEmpty == true) ? billingAddress : customerAddress;
    final city = (billingCity?.isNotEmpty == true) ? billingCity : customerCity;
    final state = (billingState?.isNotEmpty == true) ? billingState : customerState;
    final pincode = (billingPincode?.isNotEmpty == true) ? billingPincode : customerPincode;

    if (address != null && address.isNotEmpty) {
      addressParts.add(address);
    }
    if (city != null && city.isNotEmpty) {
      addressParts.add(city);
    }
    if (state != null && state.isNotEmpty) {
      addressParts.add(state);
    }
    if (pincode != null && pincode.isNotEmpty) {
      addressParts.add(pincode);
    }

    return addressParts.join(', ');
  }
  
  String get formattedCompanyAddress {
    final addressParts = <String>[];
    
    if (companyAddress != null && companyAddress!.isNotEmpty) {
      addressParts.add(companyAddress!);
    }
    if (companyCity != null && companyCity!.isNotEmpty) {
      addressParts.add(companyCity!);
    }
    if (companyState != null && companyState!.isNotEmpty) {
      addressParts.add(companyState!);
    }
    if (companyPincode != null && companyPincode!.isNotEmpty) {
      addressParts.add(companyPincode!);
    }
    
    return addressParts.join(', ');
  }
}

class InvoiceItem {
  final int id;
  final int item;
  final String itemName;
  final String itemSku;
  final String itemUnit;
  final String? itemHsnCode;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final double lineTotal;
  final double taxAmount;
  final double totalAmount;
  final double cessRate;
  final double cessAmount;
  final double cgstRate;
  final double sgstRate;
  final double igstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;

  InvoiceItem({
    required this.id,
    required this.item,
    required this.itemName,
    required this.itemSku,
    required this.itemUnit,
    this.itemHsnCode,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    required this.lineTotal,
    required this.taxAmount,
    required this.totalAmount,
    this.cessRate = 0.0,
    this.cessAmount = 0.0,
    this.cgstRate = 0.0,
    this.sgstRate = 0.0,
    this.igstRate = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      item: json['item'] is int ? json['item'] : (json['item'] != null ? int.parse(json['item'].toString()) : 0),
      itemName: json['item_name'] ?? '',
      itemSku: json['item_sku'] ?? '',
      itemUnit: json['item_unit'] ?? '',
      itemHsnCode: json['item_hsn_code'],
      quantity: json['quantity'] != null ? double.parse(json['quantity'].toString()) : 0.0,
      unitPrice: json['unit_price'] != null ? double.parse(json['unit_price'].toString()) : 0.0,
      taxRate: json['tax_rate'] != null ? double.parse(json['tax_rate'].toString()) : 0.0,
      lineTotal: json['subtotal'] != null ? double.parse(json['subtotal'].toString()) : 0.0,
      taxAmount: json['tax_amount'] != null ? double.parse(json['tax_amount'].toString()) : 0.0,
      totalAmount: json['total_amount'] != null ? double.parse(json['total_amount'].toString()) : 0.0,
      cessRate: json['cess_rate'] != null ? double.parse(json['cess_rate'].toString()) : 0.0,
      cessAmount: json['cess_amount'] != null ? double.parse(json['cess_amount'].toString()) : 0.0,
      cgstRate: json['cgst_rate'] != null ? double.parse(json['cgst_rate'].toString()) : 0.0,
      sgstRate: json['sgst_rate'] != null ? double.parse(json['sgst_rate'].toString()) : 0.0,
      igstRate: json['igst_rate'] != null ? double.parse(json['igst_rate'].toString()) : 0.0,
      cgstAmount: json['cgst_amount'] != null ? double.parse(json['cgst_amount'].toString()) : 0.0,
      sgstAmount: json['sgst_amount'] != null ? double.parse(json['sgst_amount'].toString()) : 0.0,
      igstAmount: json['igst_amount'] != null ? double.parse(json['igst_amount'].toString()) : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item': item,
      'item_name': itemName,
      'item_sku': itemSku,
      'item_unit': itemUnit,
      'item_hsn_code': itemHsnCode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tax_rate': taxRate,
      'line_total': lineTotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'cess_rate': cessRate,
      'cess_amount': cessAmount,
      'cgst_rate': cgstRate,
      'sgst_rate': sgstRate,
      'igst_rate': igstRate,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': igstAmount,
    };
  }

  // Calculate line totals
  double get calculatedLineTotal => quantity * unitPrice;
  double get calculatedTaxAmount => calculatedLineTotal * (taxRate / 100);
  double get calculatedTotalAmount => calculatedLineTotal + calculatedTaxAmount;
}

enum InvoiceStatus {
  draft('draft'),
  sent('sent'),
  paid('paid'),
  cancelled('cancelled'),
  overdue('overdue');

  const InvoiceStatus(this.value);
  final String value;

  static InvoiceStatus fromString(String value) {
    return InvoiceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InvoiceStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
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

// Helper class for creating new invoices
class InvoiceItemInput {
  final int itemId;
  final int companyId; // Company ID to distinguish same items from different companies
  final double quantity;
  final double? customPrice; // Optional custom price override
  final double? taxRate; // Optional custom tax rate

  InvoiceItemInput({
    required this.itemId,
    required this.companyId,
    required this.quantity,
    this.customPrice,
    this.taxRate,
  });

  Map<String, dynamic> toJson() {
    return {
      'item': itemId,
      'company': companyId,
      'quantity': quantity,
      'unit_price': customPrice ?? 0.0, // Will be overridden by item price if not provided
      'tax_rate': taxRate ?? 0.0, // Will be overridden by item tax rate if not provided
    };
  }
}