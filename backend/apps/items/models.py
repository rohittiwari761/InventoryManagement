from django.db import models
from django.conf import settings
from apps.companies.models import Company
from apps.stores.models import Store
import uuid


class Item(models.Model):
    UNIT_CHOICES = (
        ('kg', 'Kilogram'),
        ('g', 'Gram'),
        ('piece', 'Piece'),
        ('litre', 'Litre'),
        ('ml', 'Millilitre'),
        ('meter', 'Meter'),
        ('cm', 'Centimeter'),
        ('box', 'Box'),
        ('dozen', 'Dozen'),
    )
    
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    sku = models.CharField(max_length=100, unique=True)
    hsn_code = models.CharField(max_length=20, blank=True, null=True)
    unit = models.CharField(max_length=20, choices=UNIT_CHOICES, default='piece')
    price = models.DecimalField(max_digits=10, decimal_places=2)
    tax_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)

    companies = models.ManyToManyField(
        Company,
        related_name='items',
        help_text='Companies this item belongs to'
    )

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        company_count = self.companies.count()
        if company_count == 0:
            return f"{self.name} ({self.sku})"
        elif company_count == 1:
            return f"{self.name} ({self.sku}) - {self.companies.first().name}"
        else:
            return f"{self.name} ({self.sku}) - {company_count} companies"

    def get_company_names(self):
        """Get list of company names this item belongs to"""
        return [company.name for company in self.companies.all()]
    
    class Meta:
        db_table = 'items'


class StoreInventory(models.Model):
    item = models.ForeignKey(
        Item,
        on_delete=models.CASCADE,
        related_name='store_inventories'
    )
    store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name='inventories'
    )
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='store_inventories',
        help_text='Company this inventory entry belongs to'
    )

    quantity = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    min_stock_level = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    max_stock_level = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)

    last_updated = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.item.name} ({self.company.name}) @ {self.store.name}: {self.quantity}"

    @property
    def is_low_stock(self):
        return self.quantity <= self.min_stock_level

    def clean(self):
        """Validate that company is in item's companies"""
        from django.core.exceptions import ValidationError
        if self.company_id and self.item_id and self.company not in self.item.companies.all():
            raise ValidationError('Company must be one of the item\'s associated companies')

    class Meta:
        db_table = 'store_inventories'
        unique_together = ['item', 'store', 'company']


class InventoryTransaction(models.Model):
    TRANSACTION_TYPES = (
        ('add', 'Stock Added'),
        ('remove', 'Stock Removed'),
        ('transfer', 'Stock Transfer'),
        ('sale', 'Sale'),
        ('adjustment', 'Adjustment'),
    )
    
    inventory = models.ForeignKey(
        StoreInventory,
        on_delete=models.CASCADE,
        related_name='transactions'
    )
    
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPES)
    quantity = models.DecimalField(max_digits=10, decimal_places=2)
    notes = models.TextField(blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.transaction_type}: {self.quantity} of {self.inventory.item.name}"
    
    class Meta:
        db_table = 'inventory_transactions'


class TransferBatch(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    )

    batch_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False, db_index=True)
    from_store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name='outgoing_batches'
    )
    to_store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name='incoming_batches'
    )
    notes = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')

    # Tracking
    initiated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='initiated_batches'
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Batch {self.batch_id}: {self.from_store.name} → {self.to_store.name}"

    class Meta:
        db_table = 'transfer_batches'
        ordering = ['-created_at']


class InventoryTransfer(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    )

    # Batch relationship (nullable for backward compatibility)
    batch = models.ForeignKey(
        TransferBatch,
        on_delete=models.CASCADE,
        related_name='transfers',
        null=True,
        blank=True,
        help_text='Batch this transfer belongs to'
    )

    # Transfer details
    item = models.ForeignKey(
        Item,
        on_delete=models.CASCADE,
        related_name='transfers'
    )
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='inventory_transfers',
        help_text='Company this transfer belongs to'
    )
    from_store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name='outgoing_transfers'
    )
    to_store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name='incoming_transfers'
    )
    
    quantity = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    notes = models.TextField(blank=True, null=True)
    
    # Tracking
    initiated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='initiated_transfers'
    )
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    def __str__(self):
        return f"Transfer: {self.quantity} {self.item.name} from {self.from_store.name} to {self.to_store.name}"
    
    class Meta:
        db_table = 'inventory_transfers'
        ordering = ['-created_at']