from django.contrib import admin
from .models import Item, StoreInventory, InventoryTransaction


@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'sku', 'get_companies', 'price', 'tax_rate', 'unit', 'is_active', 'created_at')
    list_filter = ('is_active', 'companies', 'unit', 'created_at')
    search_fields = ('name', 'sku', 'hsn_code', 'companies__name')
    readonly_fields = ('created_at', 'updated_at')
    filter_horizontal = ('companies',)

    def get_companies(self, obj):
        """Display company names for list view"""
        return ", ".join([company.name for company in obj.companies.all()])
    get_companies.short_description = 'Companies'


@admin.register(StoreInventory)
class StoreInventoryAdmin(admin.ModelAdmin):
    list_display = ('item', 'store', 'quantity', 'min_stock_level', 'is_low_stock', 'last_updated')
    list_filter = ('store__company', 'store', 'last_updated')
    search_fields = ('item__name', 'item__sku', 'store__name')
    readonly_fields = ('last_updated',)


@admin.register(InventoryTransaction)
class InventoryTransactionAdmin(admin.ModelAdmin):
    list_display = ('inventory', 'transaction_type', 'quantity', 'created_at')
    list_filter = ('transaction_type', 'created_at', 'inventory__store__company')
    search_fields = ('inventory__item__name', 'notes')
    readonly_fields = ('created_at',)