from django.db import models
from django.conf import settings
from apps.companies.models import Company
from apps.stores.models import Store
from apps.items.models import Item
import uuid


class Customer(models.Model):
    name = models.CharField(max_length=255)
    email = models.EmailField(blank=True, null=True)
    phone = models.CharField(max_length=15)
    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10)
    gstin = models.CharField(max_length=15, blank=True, null=True)
    state_code = models.CharField(max_length=2, blank=True, null=True, help_text="GST State Code")
    customer_type = models.CharField(max_length=20, choices=[
        ('registered', 'Registered'),
        ('unregistered', 'Unregistered'),
        ('composition', 'Composition'),
        ('export', 'Export')
    ], default='registered')
    
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='customers'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return self.name
    
    class Meta:
        db_table = 'customers'


class Invoice(models.Model):
    INVOICE_STATUS = (
        ('draft', 'Draft'),
        ('sent', 'Sent'),
        ('paid', 'Paid'),
        ('cancelled', 'Cancelled'),
    )
    
    invoice_number = models.CharField(max_length=50, unique=True)
    invoice_date = models.DateField()
    due_date = models.DateField(blank=True, null=True)
    place_of_supply = models.CharField(max_length=100, help_text="Place of supply with state name", default="")
    reverse_charge = models.CharField(max_length=5, choices=[('Yes', 'Yes'), ('No', 'No')], default='No')
    invoice_type = models.CharField(max_length=20, choices=[
        ('tax_invoice', 'Tax Invoice'),
        ('bill_of_supply', 'Bill of Supply'),
        ('export_invoice', 'Export Invoice')
    ], default='tax_invoice')
    
    customer = models.ForeignKey(
        Customer,
        on_delete=models.CASCADE,
        related_name='invoices'
    )
    
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='invoices'
    )
    
    store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name='invoices'
    )
    
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_invoices'
    )
    
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    total_tax = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    
    cgst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    sgst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00) 
    igst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    cess_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tcs_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, help_text="Tax Collected at Source")
    round_off = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)
    
    status = models.CharField(max_length=20, choices=INVOICE_STATUS, default='draft')
    notes = models.TextField(blank=True, null=True)
    terms_and_conditions = models.TextField(default="1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged on delayed payments.\n3. Subject to jurisdiction only.\n4. All disputes subject to arbitration only.")

    # Billing Address (Optional - can override customer's default address)
    billing_address = models.TextField(blank=True, null=True, help_text="Invoice-specific billing address (leave blank to use customer's default)")
    billing_city = models.CharField(max_length=100, blank=True, null=True)
    billing_state = models.CharField(max_length=100, blank=True, null=True)
    billing_pincode = models.CharField(max_length=10, blank=True, null=True)

    # Logistics/Driver Details (Optional)
    include_logistics = models.BooleanField(default=False, help_text="Include driver/logistics details in PDF")
    driver_name = models.CharField(max_length=255, blank=True, null=True)
    driver_phone = models.CharField(max_length=15, blank=True, null=True)
    vehicle_number = models.CharField(max_length=50, blank=True, null=True)
    transport_company = models.CharField(max_length=255, blank=True, null=True)
    lr_number = models.CharField(max_length=100, blank=True, null=True, help_text="Lorry Receipt Number / Transport Document No")
    dispatch_date = models.DateField(blank=True, null=True)

    # Amount in words
    amount_in_words = models.CharField(max_length=500, blank=True, null=True)
    
    pdf_file = models.FileField(upload_to='invoices/', blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def save(self, *args, **kwargs):
        if not self.invoice_number:
            self.invoice_number = self.generate_invoice_number()
        super().save(*args, **kwargs)
    
    def generate_invoice_number(self):
        import re
        from datetime import datetime
        from django.db.models import Max
        from .utils import get_financial_year, get_fy_date_range

        # Get user settings for invoice numbering
        user = self.created_by
        prefix = user.invoice_number_prefix or 'INV'
        separator = user.invoice_number_separator or '/'
        padding = user.invoice_sequence_padding or 4
        reset_frequency = user.invoice_reset_frequency or 'yearly'

        # Use invoice_date (not created_at) to handle backdated invoices correctly
        invoice_date = self.invoice_date or datetime.now().date()

        store_code = f"S{self.store.id:02d}"

        # Determine date component and build filter based on reset frequency
        date_component = None
        invoice_filter = {'store': self.store}

        if reset_frequency == 'yearly':
            financial_year = get_financial_year(invoice_date)
            fy_start, fy_end = get_fy_date_range(invoice_date)
            date_component = financial_year
            invoice_filter['invoice_date__gte'] = fy_start
            invoice_filter['invoice_date__lte'] = fy_end
        elif reset_frequency == 'monthly':
            year_month = invoice_date.strftime('%Y%m')
            date_component = year_month
            invoice_filter['invoice_date__year'] = invoice_date.year
            invoice_filter['invoice_date__month'] = invoice_date.month

        # Build expected invoice number pattern for sequence extraction
        pattern_parts = [re.escape(prefix), re.escape(store_code)]
        if date_component:
            pattern_parts.append(re.escape(date_component))
        pattern_parts.append(r'(\d+)')  # Capture sequence number
        pattern = re.escape(separator).join(pattern_parts) + '$'

        # Get most recent invoice matching the pattern
        max_sequence = 0
        recent_invoices = Invoice.objects.filter(**invoice_filter).values_list('invoice_number', flat=True)[:100]

        for invoice_number in recent_invoices:
            match = re.match(pattern, invoice_number)
            if match:
                try:
                    sequence = int(match.group(1))
                    max_sequence = max(max_sequence, sequence)
                except (ValueError, IndexError):
                    continue

        new_sequence = max_sequence + 1

        # Build invoice number dynamically based on settings
        max_attempts = 10
        for attempt in range(max_attempts):
            # Format sequence with dynamic padding
            sequence_str = f"{new_sequence:0{padding}d}"

            # Build invoice number parts
            parts = [prefix, store_code]
            if date_component:
                parts.append(date_component)
            parts.append(sequence_str)

            invoice_number = separator.join(parts)

            # Check if this number already exists
            if not Invoice.objects.filter(invoice_number=invoice_number).exists():
                return invoice_number

            # If it exists, increment and try again
            new_sequence += 1

        # Ultimate fallsafe - use timestamp
        timestamp = int(datetime.now().timestamp())
        parts = [prefix, store_code]
        if date_component:
            parts.append(date_component)
        parts.append(str(timestamp))
        return separator.join(parts)
    
    def calculate_totals(self, items=None):
        from decimal import Decimal

        # Use provided items or query from database
        if items is None:
            items = self.items.all()

        subtotal = sum((item.subtotal for item in items), Decimal('0'))
        total_tax = sum((item.tax_amount for item in items), Decimal('0'))

        self.subtotal = subtotal
        self.total_tax = total_tax

        # Ensure cess_amount and tcs_amount are Decimals
        cess_amount = Decimal(str(self.cess_amount)) if self.cess_amount else Decimal('0')
        tcs_amount = Decimal(str(self.tcs_amount)) if self.tcs_amount else Decimal('0')

        # Calculate round off
        gross_total = subtotal + total_tax + cess_amount + tcs_amount
        rounded_total = round(gross_total)
        self.round_off = Decimal(str(rounded_total)) - gross_total
        self.total_amount = Decimal(str(rounded_total))

        cgst_total = sum((item.cgst_amount for item in items), Decimal('0'))
        sgst_total = sum((item.sgst_amount for item in items), Decimal('0'))
        igst_total = sum((item.igst_amount for item in items), Decimal('0'))

        self.cgst_amount = cgst_total
        self.sgst_amount = sgst_total
        self.igst_amount = igst_total

        # Calculate amount in words
        self.amount_in_words = self.number_to_words(int(self.total_amount))

        self.save()
    
    def number_to_words(self, number):
        """Convert number to words for amount display"""
        if number == 0:
            return "Zero Rupees Only"

        ones = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
                "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
                "Seventeen", "Eighteen", "Nineteen"]

        tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"]

        def convert_hundreds(n):
            result = ""
            if n >= 100:
                result += ones[n // 100] + " Hundred "
                n %= 100
            if n >= 20:
                result += tens[n // 10] + " "
                n %= 10
            if n > 0:
                result += ones[n] + " "
            return result

        if number < 20:
            return ones[number] + " Rupees Only"
        elif number < 100:
            return tens[number // 10] + " " + ones[number % 10] + " Rupees Only"
        elif number < 1000:
            return convert_hundreds(number) + "Rupees Only"
        elif number < 100000:
            return convert_hundreds(number // 1000) + "Thousand " + convert_hundreds(number % 1000) + "Rupees Only"
        elif number < 10000000:
            return convert_hundreds(number // 100000) + "Lakh " + convert_hundreds((number % 100000) // 1000) + "Thousand " + convert_hundreds(number % 1000) + "Rupees Only"
        else:
            return convert_hundreds(number // 10000000) + "Crore " + convert_hundreds((number % 10000000) // 100000) + "Lakh " + convert_hundreds((number % 100000) // 1000) + "Thousand " + convert_hundreds(number % 1000) + "Rupees Only"

    @property
    def is_inter_state(self):
        """
        Determine if this is an inter-state transaction based on customer and company states.
        Returns True if customer is in a different state than the company, False otherwise.
        Uses state normalization to handle abbreviations and variations (e.g., 'MP' vs 'Madhya Pradesh').
        """
        if not self.customer or not self.company:
            return False

        customer_state = self.customer.state if self.customer.state else ''
        company_state = self.company.state if self.company.state else ''

        # Return False if either state is missing
        if not customer_state or not company_state:
            return False

        # Use state normalization to handle variations and abbreviations
        from .state_mapper import normalize_state_name

        normalized_customer_state = normalize_state_name(customer_state)
        normalized_company_state = normalize_state_name(company_state)

        # Inter-state if normalized states are different
        return normalized_customer_state != normalized_company_state

    def __str__(self):
        return f"{self.invoice_number} - {self.customer.name}"
    
    class Meta:
        db_table = 'invoices'


class InvoiceItem(models.Model):
    invoice = models.ForeignKey(
        Invoice,
        on_delete=models.CASCADE,
        related_name='items'
    )
    
    item = models.ForeignKey(
        Item,
        on_delete=models.CASCADE,
        related_name='invoice_items'
    )
    
    quantity = models.DecimalField(max_digits=10, decimal_places=2)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    tax_rate = models.DecimalField(max_digits=5, decimal_places=2)
    
    subtotal = models.DecimalField(max_digits=12, decimal_places=2)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2)
    
    cgst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)
    sgst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)
    igst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)
    
    cgst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    sgst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    igst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    cess_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)
    cess_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    
    def calculate_taxes(self, is_inter_state=None):
        """Calculate tax amounts based on customer and company states

        Args:
            is_inter_state: Optional boolean to avoid recalculating state comparison.
                          If None, will calculate from invoice customer/company states.
        """
        import logging
        logger = logging.getLogger(__name__)

        # Ensure all values are Decimals
        from decimal import Decimal
        if not isinstance(self.quantity, Decimal):
            self.quantity = Decimal(str(self.quantity))
        if not isinstance(self.unit_price, Decimal):
            self.unit_price = Decimal(str(self.unit_price))
        if not isinstance(self.tax_rate, Decimal):
            self.tax_rate = Decimal(str(self.tax_rate))
        if not isinstance(self.cess_rate, Decimal):
            self.cess_rate = Decimal(str(self.cess_rate))

        self.subtotal = self.quantity * self.unit_price

        # Use provided is_inter_state or calculate it
        if is_inter_state is None:
            # Default to intra-state (CGST + SGST) if customer info not available
            is_inter_state = False

            if hasattr(self.invoice, 'customer') and self.invoice.customer:
                customer_state = self.invoice.customer.state.lower() if self.invoice.customer.state else ''
                company_state = self.invoice.company.state.lower() if self.invoice.company.state else ''
                is_inter_state = customer_state != company_state and customer_state and company_state

        from decimal import Decimal
        zero = Decimal('0')
        two = Decimal('2')

        if is_inter_state:
            # Inter-state transaction - use IGST
            self.cgst_rate = zero
            self.sgst_rate = zero
            self.igst_rate = self.tax_rate
        else:
            # Intra-state transaction - use CGST + SGST
            self.cgst_rate = self.tax_rate / two
            self.sgst_rate = self.tax_rate / two
            self.igst_rate = zero

        from decimal import Decimal
        hundred = Decimal('100')

        self.cgst_amount = (self.subtotal * self.cgst_rate) / hundred
        self.sgst_amount = (self.subtotal * self.sgst_rate) / hundred
        self.igst_amount = (self.subtotal * self.igst_rate) / hundred

        # Calculate cess
        self.cess_amount = (self.subtotal * self.cess_rate) / hundred

        self.tax_amount = self.cgst_amount + self.sgst_amount + self.igst_amount + self.cess_amount
        self.total_amount = self.subtotal + self.tax_amount
    
    def save(self, *args, **kwargs):
        self.calculate_taxes()
        super().save(*args, **kwargs)
    
    def __str__(self):
        return f"{self.item.name} x {self.quantity}"
    
    class Meta:
        db_table = 'invoice_items'