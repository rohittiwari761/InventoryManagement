from rest_framework import serializers
from .models import Item, StoreInventory, InventoryTransaction, InventoryTransfer, TransferBatch


class ItemSerializer(serializers.ModelSerializer):
    company_names = serializers.SerializerMethodField()

    class Meta:
        model = Item
        fields = (
            'id', 'name', 'description', 'sku', 'hsn_code', 'unit', 'price',
            'tax_rate', 'companies', 'company_names', 'is_active', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Set queryset for companies field dynamically based on request user
        request = self.context.get('request')
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            from apps.companies.models import Company
            self.fields['companies'].queryset = Company.objects.filter(owner=request.user)

    def get_company_names(self, obj):
        """Get list of company names ordered by ID to match companies field"""
        return [company.name for company in obj.companies.all().order_by('id')]

    def validate_companies(self, value):
        """Ensure at least one company is selected"""
        if not value or len(value) == 0:
            raise serializers.ValidationError("At least one company must be selected")
        return value

    def create(self, validated_data):
        companies_data = validated_data.pop('companies', [])
        item = Item.objects.create(**validated_data)
        item.companies.set(companies_data)
        return item

    def update(self, instance, validated_data):
        companies_data = validated_data.pop('companies', None)

        # Update regular fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        # Update companies if provided
        if companies_data is not None:
            instance.companies.set(companies_data)

        return instance


class StoreInventorySerializer(serializers.ModelSerializer):
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_sku = serializers.CharField(source='item.sku', read_only=True)
    item_unit = serializers.CharField(source='item.unit', read_only=True)
    item_price = serializers.DecimalField(source='item.price', max_digits=10, decimal_places=2, read_only=True)
    store_name = serializers.CharField(source='store.name', read_only=True)
    company_name = serializers.CharField(source='company.name', read_only=True)

    class Meta:
        model = StoreInventory
        fields = (
            'id', 'item', 'item_name', 'item_sku', 'item_unit', 'item_price',
            'store', 'store_name', 'company', 'company_name',
            'quantity', 'min_stock_level', 'max_stock_level',
            'is_low_stock', 'last_updated'
        )
        read_only_fields = ('id', 'is_low_stock', 'last_updated')

    def validate(self, data):
        """Validate company is in item's companies"""
        item = data.get('item')
        company = data.get('company')

        # For updates, get existing values if not provided
        if self.instance:
            item = item or self.instance.item
            company = company or self.instance.company

        if company and item and company not in item.companies.all():
            raise serializers.ValidationError({
                'company': 'Company must be one of the item\'s associated companies'
            })

        return data


class InventoryTransactionSerializer(serializers.ModelSerializer):
    item_name = serializers.CharField(source='inventory.item.name', read_only=True)
    store_name = serializers.CharField(source='inventory.store.name', read_only=True)
    
    class Meta:
        model = InventoryTransaction
        fields = (
            'id', 'inventory', 'item_name', 'store_name', 'transaction_type',
            'quantity', 'notes', 'created_at'
        )
        read_only_fields = ('id', 'created_at')


class ItemWithInventorySerializer(ItemSerializer):
    store_inventories = StoreInventorySerializer(many=True, read_only=True)
    
    class Meta(ItemSerializer.Meta):
        fields = ItemSerializer.Meta.fields + ('store_inventories',)


class InventoryTransferSerializer(serializers.ModelSerializer):
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_sku = serializers.CharField(source='item.sku', read_only=True)
    item_unit = serializers.CharField(source='item.unit', read_only=True)
    company_name = serializers.CharField(source='company.name', read_only=True)
    from_store_name = serializers.CharField(source='from_store.name', read_only=True)
    to_store_name = serializers.CharField(source='to_store.name', read_only=True)
    initiated_by_name = serializers.CharField(source='initiated_by.get_full_name', read_only=True)

    class Meta:
        model = InventoryTransfer
        fields = (
            'id', 'item', 'item_name', 'item_sku', 'item_unit',
            'company', 'company_name',
            'from_store', 'from_store_name', 'to_store', 'to_store_name',
            'quantity', 'status', 'notes', 'initiated_by', 'initiated_by_name',
            'created_at', 'completed_at'
        )
        read_only_fields = ('id', 'initiated_by', 'created_at', 'completed_at')


class CreateInventoryTransferSerializer(serializers.ModelSerializer):
    class Meta:
        model = InventoryTransfer
        fields = ('item', 'company', 'from_store', 'to_store', 'quantity', 'notes')

    def validate(self, data):
        item = data.get('item')
        company = data.get('company')
        from_store = data.get('from_store')
        to_store = data.get('to_store')
        quantity = data.get('quantity')

        # Ensure from_store and to_store are different
        if from_store == to_store:
            raise serializers.ValidationError("Source and destination stores must be different")

        # Validate that company is in item's companies
        if company and item and company not in item.companies.all():
            raise serializers.ValidationError({
                'company': 'Company must be one of the item\'s associated companies'
            })

        # Check if source store has enough inventory for this company
        if item and from_store and company and quantity:
            try:
                source_inventory = StoreInventory.objects.get(
                    item=item,
                    store=from_store,
                    company=company
                )
                if source_inventory.quantity < quantity:
                    raise serializers.ValidationError(
                        f"Insufficient inventory. Available: {source_inventory.quantity}, "
                        f"Requested: {quantity}"
                    )
            except StoreInventory.DoesNotExist:
                raise serializers.ValidationError("Item not found in source store for this company")

        return data


class TransferBatchSerializer(serializers.ModelSerializer):
    from_store_name = serializers.CharField(source='from_store.name', read_only=True)
    to_store_name = serializers.CharField(source='to_store.name', read_only=True)
    initiated_by_name = serializers.CharField(source='initiated_by.get_full_name', read_only=True)
    transfers = InventoryTransferSerializer(many=True, read_only=True)
    transfer_count = serializers.SerializerMethodField()
    total_items = serializers.SerializerMethodField()

    class Meta:
        model = TransferBatch
        fields = (
            'id', 'batch_id', 'from_store', 'from_store_name',
            'to_store', 'to_store_name', 'notes', 'status',
            'initiated_by', 'initiated_by_name', 'created_at', 'completed_at',
            'transfers', 'transfer_count', 'total_items'
        )
        read_only_fields = ('id', 'batch_id', 'initiated_by', 'created_at', 'completed_at')

    def get_transfer_count(self, obj):
        return obj.transfers.count()

    def get_total_items(self, obj):
        return sum(float(transfer.quantity) for transfer in obj.transfers.all())