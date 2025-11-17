from django.contrib import admin
from .models import Customer, Invoice, InvoiceItem


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ('name', 'email', 'phone', 'company', 'city', 'state', 'created_at')
    list_filter = ('company', 'state', 'created_at')
    search_fields = ('name', 'email', 'phone', 'gstin')
    readonly_fields = ('created_at', 'updated_at')


class InvoiceItemInline(admin.TabularInline):
    model = InvoiceItem
    extra = 0
    readonly_fields = ('subtotal', 'tax_amount', 'total_amount', 'cgst_amount', 'sgst_amount', 'igst_amount')


@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ('invoice_number', 'customer', 'store', 'total_amount', 'status', 'invoice_date', 'created_at')
    list_filter = ('status', 'company', 'store', 'invoice_date', 'created_at')
    search_fields = ('invoice_number', 'customer__name', 'customer__phone')
    readonly_fields = ('invoice_number', 'subtotal', 'total_tax', 'total_amount', 'cgst_amount', 'sgst_amount', 'igst_amount', 'created_at', 'updated_at')
    inlines = [InvoiceItemInline]


@admin.register(InvoiceItem)
class InvoiceItemAdmin(admin.ModelAdmin):
    list_display = ('invoice', 'item', 'quantity', 'unit_price', 'total_amount')
    list_filter = ('invoice__company', 'invoice__store', 'item')
    search_fields = ('invoice__invoice_number', 'item__name')
    readonly_fields = ('subtotal', 'tax_amount', 'total_amount', 'cgst_amount', 'sgst_amount', 'igst_amount')