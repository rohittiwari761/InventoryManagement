from rest_framework import serializers
from .models import Customer, Invoice, InvoiceItem
from apps.companies.models import Company
from apps.stores.models import Store


class CustomerSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    
    class Meta:
        model = Customer
        fields = (
            'id', 'name', 'email', 'phone', 'address', 'city', 'state', 'pincode',
            'gstin', 'state_code', 'customer_type', 'company', 'company_name', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class InvoiceItemSerializer(serializers.ModelSerializer):
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_sku = serializers.CharField(source='item.sku', read_only=True)
    item_unit = serializers.CharField(source='item.unit', read_only=True)
    item_hsn_code = serializers.CharField(source='item.hsn_code', read_only=True)
    # Company is write-only - used to determine which inventory to deduct from, not stored in invoice item
    company = serializers.PrimaryKeyRelatedField(queryset=Company.objects.all(), required=False, allow_null=True, write_only=True)

    class Meta:
        model = InvoiceItem
        fields = (
            'id', 'item', 'company', 'item_name', 'item_sku', 'item_unit', 'item_hsn_code', 'quantity',
            'unit_price', 'tax_rate', 'subtotal', 'tax_amount', 'total_amount',
            'cgst_rate', 'sgst_rate', 'igst_rate', 'cgst_amount', 'sgst_amount', 'igst_amount',
            'cess_rate', 'cess_amount'
        )
        read_only_fields = (
            'id', 'subtotal', 'tax_amount', 'total_amount', 'cgst_rate', 'sgst_rate',
            'igst_rate', 'cgst_amount', 'sgst_amount', 'igst_amount', 'cess_rate', 'cess_amount'
        )


class InvoiceListSerializer(serializers.ModelSerializer):
    """
    Lightweight serializer for invoice list view.
    Only includes essential fields to minimize payload size and improve performance.
    Use InvoiceSerializer for detail view where all fields are needed.
    """
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_gstin = serializers.CharField(source='customer.gstin', read_only=True)
    customer_state = serializers.CharField(source='customer.state', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    financial_year = serializers.SerializerMethodField()

    def get_financial_year(self, obj):
        """Calculate financial year from invoice date (April-March)"""
        from .utils import get_financial_year
        return get_financial_year(obj.invoice_date)

    class Meta:
        model = Invoice
        fields = (
            'id',
            'invoice_number',
            'customer_name',
            'customer_gstin',
            'customer_state',
            'total_amount',
            'subtotal',
            'total_tax',
            'status',
            'status_display',
            'invoice_date',
            'due_date',
            'created_at',
            'cgst_amount',
            'sgst_amount',
            'igst_amount',
            'is_inter_state',
            'financial_year',
            'invoice_type',
            'place_of_supply',
        )
        read_only_fields = ('id', 'created_at')


class InvoiceSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    company_name = serializers.CharField(source='company.name', read_only=True)
    store_name = serializers.CharField(source='store.name', read_only=True)
    creator_layout_preference = serializers.CharField(source='created_by.invoice_layout_preference', read_only=True)
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    financial_year = serializers.SerializerMethodField()
    is_inter_state = serializers.SerializerMethodField()

    # Add customer fields for Flutter compatibility
    customer_address = serializers.CharField(source='customer.address', read_only=True)
    customer_city = serializers.CharField(source='customer.city', read_only=True)
    customer_state = serializers.CharField(source='customer.state', read_only=True)
    customer_pincode = serializers.CharField(source='customer.pincode', read_only=True)
    customer_gstin = serializers.CharField(source='customer.gstin', read_only=True)
    customer_phone = serializers.CharField(source='customer.phone', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)

    # Add comprehensive company/seller fields for invoice display
    company_address = serializers.CharField(source='company.address', read_only=True)
    company_city = serializers.CharField(source='company.city', read_only=True)
    company_state = serializers.CharField(source='company.state', read_only=True)
    company_pincode = serializers.CharField(source='company.pincode', read_only=True)
    company_phone = serializers.CharField(source='company.phone', read_only=True)
    company_email = serializers.CharField(source='company.email', read_only=True)
    company_gstin = serializers.CharField(source='company.gstin', read_only=True)
    company_pan = serializers.CharField(source='company.pan', read_only=True)
    company_state_code = serializers.CharField(source='company.state_code', read_only=True)
    company_bank_name = serializers.CharField(source='company.bank_name', read_only=True, allow_null=True)
    company_bank_account_number = serializers.CharField(source='company.bank_account_number', read_only=True, allow_null=True)
    company_bank_ifsc = serializers.CharField(source='company.bank_ifsc', read_only=True, allow_null=True)
    company_bank_branch = serializers.CharField(source='company.bank_branch', read_only=True, allow_null=True)

    def get_financial_year(self, obj):
        """Calculate financial year from invoice date (April-March)"""
        from .utils import get_financial_year
        return get_financial_year(obj.invoice_date)

    def get_is_inter_state(self, obj):
        """Get whether this is an inter-state transaction"""
        return obj.is_inter_state
    
    class Meta:
        model = Invoice
        fields = (
            'id', 'invoice_number', 'invoice_date', 'due_date', 'customer', 'customer_name',
            'company', 'company_name', 'store', 'store_name', 'creator_layout_preference', 'created_by', 'created_by_name',
            'financial_year', 'is_inter_state', 'subtotal', 'total_tax', 'total_amount', 'cgst_amount', 'sgst_amount', 'igst_amount',
            'cess_amount', 'tcs_amount', 'round_off', 'place_of_supply', 'reverse_charge', 'invoice_type',
            'terms_and_conditions', 'amount_in_words', 'status', 'notes', 'pdf_file', 'created_at', 'updated_at',
            'customer_address', 'customer_city', 'customer_state', 'customer_pincode',
            'customer_gstin', 'customer_phone', 'customer_email',
            'company_address', 'company_city', 'company_state', 'company_pincode',
            'company_phone', 'company_email', 'company_gstin', 'company_pan', 'company_state_code',
            'company_bank_name', 'company_bank_account_number', 'company_bank_ifsc', 'company_bank_branch',
            # Billing address fields
            'billing_address', 'billing_city', 'billing_state', 'billing_pincode',
            # Logistics fields
            'include_logistics', 'driver_name', 'driver_phone', 'vehicle_number',
            'transport_company', 'lr_number', 'dispatch_date'
        )
        read_only_fields = (
            'id', 'invoice_number', 'subtotal', 'total_tax', 'total_amount',
            'cgst_amount', 'sgst_amount', 'igst_amount', 'cess_amount', 'tcs_amount', 'round_off',
            'amount_in_words', 'created_by', 'created_at', 'updated_at'
        )


class InvoiceDetailSerializer(InvoiceSerializer):
    items = InvoiceItemSerializer(many=True, read_only=True)
    customer_details = CustomerSerializer(source='customer', read_only=True)
    
    class Meta(InvoiceSerializer.Meta):
        fields = InvoiceSerializer.Meta.fields + ('items', 'customer_details')


class InvoiceCreateSerializer(serializers.ModelSerializer):
    items = InvoiceItemSerializer(many=True)
    
    # Optional fields with defaults
    invoice_date = serializers.DateField(required=False)
    due_date = serializers.DateField(required=False, allow_null=True)
    place_of_supply = serializers.CharField(required=False, allow_blank=True)
    reverse_charge = serializers.CharField(required=False, default='No')
    invoice_type = serializers.CharField(required=False, default='tax_invoice')
    terms_and_conditions = serializers.CharField(required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    company = serializers.PrimaryKeyRelatedField(queryset=Company.objects.all(), required=False)
    store = serializers.PrimaryKeyRelatedField(queryset=Store.objects.all(), required=False)
    
    # Customer fields for creation
    customer_name = serializers.CharField(write_only=True, required=False, default='Walk-in Customer')
    customer_email = serializers.EmailField(write_only=True, required=False, allow_blank=True)
    customer_phone = serializers.CharField(write_only=True, required=False, allow_blank=True)
    customer_address = serializers.CharField(write_only=True, required=False, allow_blank=True)
    customer_city = serializers.CharField(write_only=True, required=False, allow_blank=True)
    customer_state = serializers.CharField(write_only=True, required=False, allow_blank=True)
    customer_pincode = serializers.CharField(write_only=True, required=False, allow_blank=True)
    customer_gstin = serializers.CharField(write_only=True, required=False, allow_blank=True)

    # Billing address fields (optional)
    billing_address = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    billing_city = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    billing_state = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    billing_pincode = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    # Logistics fields (optional)
    include_logistics = serializers.BooleanField(required=False, default=False)
    driver_name = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    driver_phone = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    vehicle_number = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    transport_company = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    lr_number = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    dispatch_date = serializers.DateField(required=False, allow_null=True)

    class Meta:
        model = Invoice
        fields = (
            'invoice_date', 'due_date', 'company', 'store',
            'place_of_supply', 'reverse_charge', 'invoice_type', 'terms_and_conditions',
            'notes', 'items', 'customer_name', 'customer_email', 'customer_phone',
            'customer_address', 'customer_city', 'customer_state', 'customer_pincode', 'customer_gstin',
            # Billing address fields
            'billing_address', 'billing_city', 'billing_state', 'billing_pincode',
            # Logistics fields
            'include_logistics', 'driver_name', 'driver_phone', 'vehicle_number',
            'transport_company', 'lr_number', 'dispatch_date'
        )
    
    def validate(self, data):
        return data
    
    def create(self, validated_data):
        from datetime import date
        from django.db import transaction
        
        # Use database transaction for atomicity
        with transaction.atomic():
            # Extract items data safely
            items_data = validated_data.pop('items', [])
        
            # Set defaults for missing fields
            if 'invoice_date' not in validated_data or not validated_data['invoice_date']:
                validated_data['invoice_date'] = date.today()
            if 'terms_and_conditions' not in validated_data or not validated_data['terms_and_conditions']:
                validated_data['terms_and_conditions'] = "1. Goods once sold will not be taken back.\\n2. Interest @ 18% p.a. will be charged on delayed payments.\\n3. Subject to jurisdiction only.\\n4. All disputes subject to arbitration only."
        
            # Get company and store objects - should be set by perform_create
            from apps.companies.models import Company
            from apps.stores.models import Store
            
            if 'company' not in validated_data:
                raise serializers.ValidationError("Company not specified")
            if 'store' not in validated_data:
                raise serializers.ValidationError("Store not specified")
            
            company_obj = validated_data['company']
            if isinstance(company_obj, int):
                company_obj = Company.objects.get(pk=company_obj)
                validated_data['company'] = company_obj
                
            store_obj = validated_data['store']
            if isinstance(store_obj, int):
                store_obj = Store.objects.get(pk=store_obj)
                validated_data['store'] = store_obj
            
            # Extract customer data with proper defaults for required fields
            customer_state = validated_data.pop('customer_state', '') or company_obj.state or 'Unknown'
            customer_name = validated_data.pop('customer_name', 'Walk-in Customer')
            customer_email = validated_data.pop('customer_email', '')
            customer_phone = validated_data.pop('customer_phone', '') or '0000000000'
            customer_address = validated_data.pop('customer_address', '') or 'N/A'
            customer_city = validated_data.pop('customer_city', '') or 'Unknown'
            customer_pincode = validated_data.pop('customer_pincode', '') or '000000'
            customer_gstin = validated_data.pop('customer_gstin', '')

            customer_data = {
                'name': customer_name,
                'email': customer_email,
                'phone': customer_phone,
                'address': customer_address,
                'city': customer_city,
                'state': customer_state,
                'pincode': customer_pincode,
                'gstin': customer_gstin,
                'company': company_obj
            }

            # Create or get customer
            try:
                customer, created = Customer.objects.get_or_create(
                    name=customer_data['name'],
                    company=customer_data['company'],
                    defaults=customer_data
                )
            except Exception as e:
                raise serializers.ValidationError(f"Customer creation failed: {str(e)}")

            validated_data['customer'] = customer
            validated_data['created_by'] = self.context['request'].user

            # Snapshot the address FROM THE FORM (not from customer record) as billing address
            # This ensures invoice shows the address entered during creation, not customer's current address
            if not validated_data.get('billing_address'):
                validated_data['billing_address'] = customer_address
            if not validated_data.get('billing_city'):
                validated_data['billing_city'] = customer_city
            if not validated_data.get('billing_state'):
                validated_data['billing_state'] = customer_state
            if not validated_data.get('billing_pincode'):
                validated_data['billing_pincode'] = customer_pincode

            # Set default place_of_supply if not provided
            if not validated_data.get('place_of_supply'):
                validated_data['place_of_supply'] = company_obj.state or 'Unknown'

            try:
                invoice = Invoice.objects.create(**validated_data)
            except Exception as e:
                raise serializers.ValidationError(f"Invoice creation failed: {str(e)}")

            # PERFORMANCE OPTIMIZATION: Prefetch all items and inventory in bulk
            from apps.items.models import Item, StoreInventory, InventoryTransaction

            # Extract all item IDs from the request
            item_ids = []
            for item_data in items_data:
                item_id = item_data['item'].pk if hasattr(item_data['item'], 'pk') else item_data['item']
                item_ids.append(item_id)

            # Bulk fetch all items in a single query
            items_dict = {item.pk: item for item in Item.objects.filter(pk__in=item_ids)}

            # Bulk fetch all store inventory in a single query
            store_id = validated_data['store'].pk if hasattr(validated_data['store'], 'pk') else validated_data['store']
            store_inventory_qs = StoreInventory.objects.filter(
                item__pk__in=item_ids,
                store_id=store_id
            ).select_related('item')

            # Create inventory lookup dict for O(1) access
            inventory_dict = {}
            for inv in store_inventory_qs:
                company_id = inv.company_id
                key = (inv.item.pk, company_id)
                inventory_dict[key] = inv

            # Create invoice items and deduct inventory
            invoice_items = []
            transactions_to_create = []
            inventories_to_update = []

            for i, item_data in enumerate(items_data):
                try:
                    # Get the item from prefetched dict (O(1) lookup instead of database query)
                    item_id = item_data['item'].pk if hasattr(item_data['item'], 'pk') else item_data['item']
                    item = items_dict.get(item_id)
                    if not item:
                        raise serializers.ValidationError(f"Item with ID {item_id} not found")
                    
                    # Use item's default price and tax rate if not provided
                    if not item_data.get('unit_price') or item_data.get('unit_price', 0) == 0:
                        item_data['unit_price'] = item.price
                    
                    # ALWAYS use the item's stored tax rate to ensure consistency
                    item_data['tax_rate'] = item.tax_rate
                    
                    # Convert to Decimal to ensure proper calculation
                    from decimal import Decimal
                    item_data['quantity'] = Decimal(str(item_data['quantity']))
                    item_data['unit_price'] = Decimal(str(item_data['unit_price']))
                    item_data['tax_rate'] = Decimal(str(item_data['tax_rate']))
                    
                    # Check and deduct inventory from store
                    # Get company ID from item data (for multi-company support)
                    company_id = item_data.get('company')
                    if company_id:
                        if hasattr(company_id, 'pk'):
                            company_id = company_id.pk
                    else:
                        # Fallback to invoice company if not specified
                        company_id = validated_data['company'].pk

                    # Remove company from item_data as it's not a field in InvoiceItem model
                    item_data.pop('company', None)

                    # Get inventory from prefetched dict (O(1) lookup instead of database query)
                    inventory_key = (item.pk, company_id)
                    store_inventory = inventory_dict.get(inventory_key)

                    if not store_inventory:
                        raise serializers.ValidationError(
                            f"Item '{item.name}' is not available in store '{validated_data['store'].name}'"
                        )

                    # Check if sufficient quantity is available
                    if store_inventory.quantity < item_data['quantity']:
                        # Improved error handling: Return structured error data for better UX
                        raise serializers.ValidationError({
                            'type': 'insufficient_inventory',
                            'item_name': item.name,
                            'item_id': item.id,
                            'available_quantity': float(store_inventory.quantity),
                            'requested_quantity': float(item_data['quantity']),
                            'shortage': float(item_data['quantity'] - store_inventory.quantity),
                            'message': f"Not enough stock available for {item.name}. You need {float(item_data['quantity'] - store_inventory.quantity)} more units.",
                            'user_message': f"Insufficient stock for {item.name}",
                            'suggestion': f"Only {float(store_inventory.quantity)} units available. Please reduce quantity or restock inventory."
                        })

                    # Deduct quantity from inventory (will be saved in bulk later)
                    store_inventory.quantity -= item_data['quantity']
                    inventories_to_update.append(store_inventory)

                    # Prepare transaction for bulk creation
                    transactions_to_create.append(
                        InventoryTransaction(
                            inventory=store_inventory,
                            transaction_type='sale',
                            quantity=-item_data['quantity'],  # Negative for deduction
                            notes=f"Sale via Invoice #{invoice.invoice_number}"
                        )
                    )
                    
                    # Set required fields with defaults
                    item_data['subtotal'] = item_data['quantity'] * item_data['unit_price']
                    item_data['tax_amount'] = Decimal('0')  # Will be calculated by save method
                    item_data['total_amount'] = Decimal('0')  # Will be calculated by save method

                    # Prepare invoice item for bulk creation
                    invoice_item = InvoiceItem(invoice=invoice, **item_data)
                    invoice_items.append(invoice_item)

                except Exception as e:
                    raise serializers.ValidationError(f"Invoice item {i+1} creation failed: {str(e)}")

            # PERFORMANCE OPTIMIZATION: Bulk create all invoice items in a single query
            if invoice_items:
                invoice_items = InvoiceItem.objects.bulk_create(invoice_items)

            # PERFORMANCE OPTIMIZATION: Bulk update all inventory quantities in a single query
            if inventories_to_update:
                StoreInventory.objects.bulk_update(inventories_to_update, ['quantity'])

            # PERFORMANCE OPTIMIZATION: Bulk create all transactions in a single query
            if transactions_to_create:
                InventoryTransaction.objects.bulk_create(transactions_to_create)

            # PERFORMANCE OPTIMIZATION: Reuse bulk-created items instead of re-querying
            # Manually attach required relations to avoid database query
            for invoice_item in invoice_items:
                invoice_item.invoice = invoice
                invoice_item.invoice.customer = customer
                invoice_item.invoice.company = validated_data['company']

            # PERFORMANCE OPTIMIZATION: Calculate is_inter_state once for all items
            is_inter_state = False
            if customer:
                customer_state = customer.state.lower() if customer.state else ''
                company_state = validated_data['company'].state.lower() if validated_data['company'].state else ''
                is_inter_state = customer_state != company_state and customer_state and company_state

            # Calculate taxes for all items (using in-memory objects and cached is_inter_state)
            items_to_update = []
            for invoice_item in invoice_items:
                try:
                    invoice_item.calculate_taxes(is_inter_state=is_inter_state)
                    items_to_update.append(invoice_item)
                except Exception as e:
                    pass  # Log error if needed for debugging

            # PERFORMANCE OPTIMIZATION: Bulk update tax calculations
            # Include all tax-related fields to ensure GST breakdown is saved correctly
            if items_to_update:
                InvoiceItem.objects.bulk_update(
                    items_to_update,
                    ['subtotal', 'cgst_rate', 'sgst_rate', 'igst_rate',
                     'cgst_amount', 'sgst_amount', 'igst_amount',
                     'cess_amount', 'tax_amount', 'total_amount']
                )

            # Calculate invoice totals (passing items to avoid redundant query)
            try:
                invoice.calculate_totals(items=items_to_update if items_to_update else invoice_items)
            except Exception as e:
                pass  # Log error if needed for debugging

            return invoice