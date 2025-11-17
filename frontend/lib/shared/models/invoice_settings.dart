/// Model for user invoice settings
class InvoiceSettings {
  // Layout Settings
  final String invoiceLayoutPreference;
  final bool allowStoreOverride;

  // Default Values
  final int invoiceDefaultPaymentTerms;
  final double invoiceDefaultTaxRate;
  final int invoiceValidityDays;
  final String? invoiceTermsAndConditions;

  // Numbering Configuration
  final String invoiceNumberPrefix;
  final String invoiceNumberSeparator;
  final int invoiceSequencePadding;
  final String invoiceResetFrequency;

  InvoiceSettings({
    required this.invoiceLayoutPreference,
    required this.allowStoreOverride,
    required this.invoiceDefaultPaymentTerms,
    required this.invoiceDefaultTaxRate,
    required this.invoiceValidityDays,
    this.invoiceTermsAndConditions,
    required this.invoiceNumberPrefix,
    required this.invoiceNumberSeparator,
    required this.invoiceSequencePadding,
    required this.invoiceResetFrequency,
  });

  factory InvoiceSettings.fromJson(Map<String, dynamic> json) {
    return InvoiceSettings(
      invoiceLayoutPreference: json['invoice_layout_preference'] ?? 'classic',
      allowStoreOverride: json['allow_store_override'] ?? true,
      invoiceDefaultPaymentTerms: json['invoice_default_payment_terms'] ?? 30,
      invoiceDefaultTaxRate: (json['invoice_default_tax_rate'] is String)
          ? double.parse(json['invoice_default_tax_rate'])
          : (json['invoice_default_tax_rate'] ?? 18.0).toDouble(),
      invoiceValidityDays: json['invoice_validity_days'] ?? 30,
      invoiceTermsAndConditions: json['invoice_terms_and_conditions'],
      invoiceNumberPrefix: json['invoice_number_prefix'] ?? 'INV',
      invoiceNumberSeparator: json['invoice_number_separator'] ?? '/',
      invoiceSequencePadding: json['invoice_sequence_padding'] ?? 4,
      invoiceResetFrequency: json['invoice_reset_frequency'] ?? 'yearly',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_layout_preference': invoiceLayoutPreference,
      'allow_store_override': allowStoreOverride,
      'invoice_default_payment_terms': invoiceDefaultPaymentTerms,
      'invoice_default_tax_rate': invoiceDefaultTaxRate,
      'invoice_validity_days': invoiceValidityDays,
      'invoice_terms_and_conditions': invoiceTermsAndConditions,
      'invoice_number_prefix': invoiceNumberPrefix,
      'invoice_number_separator': invoiceNumberSeparator,
      'invoice_sequence_padding': invoiceSequencePadding,
      'invoice_reset_frequency': invoiceResetFrequency,
    };
  }

  /// Create a copy with updated values
  InvoiceSettings copyWith({
    String? invoiceLayoutPreference,
    bool? allowStoreOverride,
    int? invoiceDefaultPaymentTerms,
    double? invoiceDefaultTaxRate,
    int? invoiceValidityDays,
    String? invoiceTermsAndConditions,
    String? invoiceNumberPrefix,
    String? invoiceNumberSeparator,
    int? invoiceSequencePadding,
    String? invoiceResetFrequency,
  }) {
    return InvoiceSettings(
      invoiceLayoutPreference: invoiceLayoutPreference ?? this.invoiceLayoutPreference,
      allowStoreOverride: allowStoreOverride ?? this.allowStoreOverride,
      invoiceDefaultPaymentTerms: invoiceDefaultPaymentTerms ?? this.invoiceDefaultPaymentTerms,
      invoiceDefaultTaxRate: invoiceDefaultTaxRate ?? this.invoiceDefaultTaxRate,
      invoiceValidityDays: invoiceValidityDays ?? this.invoiceValidityDays,
      invoiceTermsAndConditions: invoiceTermsAndConditions ?? this.invoiceTermsAndConditions,
      invoiceNumberPrefix: invoiceNumberPrefix ?? this.invoiceNumberPrefix,
      invoiceNumberSeparator: invoiceNumberSeparator ?? this.invoiceNumberSeparator,
      invoiceSequencePadding: invoiceSequencePadding ?? this.invoiceSequencePadding,
      invoiceResetFrequency: invoiceResetFrequency ?? this.invoiceResetFrequency,
    );
  }

  /// Default settings
  static InvoiceSettings defaults() {
    return InvoiceSettings(
      invoiceLayoutPreference: 'classic',
      allowStoreOverride: true,
      invoiceDefaultPaymentTerms: 30,
      invoiceDefaultTaxRate: 18.0,
      invoiceValidityDays: 30,
      invoiceTermsAndConditions: '1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged on delayed payments.\n3. Subject to jurisdiction only.\n4. All disputes subject to arbitration only.',
      invoiceNumberPrefix: 'INV',
      invoiceNumberSeparator: '/',
      invoiceSequencePadding: 4,
      invoiceResetFrequency: 'yearly',
    );
  }
}
