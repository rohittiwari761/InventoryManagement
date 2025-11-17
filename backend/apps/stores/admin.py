from django.contrib import admin
from .models import Store, StoreUser


@admin.register(Store)
class StoreAdmin(admin.ModelAdmin):
    list_display = ('name', 'company', 'manager', 'city', 'state', 'is_active', 'created_at')
    list_filter = ('is_active', 'state', 'company', 'created_at')
    search_fields = ('name', 'company__name', 'city', 'manager__email')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(StoreUser)
class StoreUserAdmin(admin.ModelAdmin):
    list_display = ('user', 'store', 'is_active', 'assigned_at')
    list_filter = ('is_active', 'store__company', 'assigned_at')
    search_fields = ('user__email', 'store__name')