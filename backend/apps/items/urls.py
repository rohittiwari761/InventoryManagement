from django.urls import path
from . import views

urlpatterns = [
    path('', views.ItemListCreateView.as_view(), name='item-list-create'),
    path('<int:pk>/', views.ItemDetailView.as_view(), name='item-detail'),
    path('inventory/', views.StoreInventoryListCreateView.as_view(), name='inventory-list-create'),
    path('inventory/<int:pk>/', views.StoreInventoryDetailView.as_view(), name='inventory-detail'),
    path('inventory/store/<int:store_id>/', views.store_inventory_view, name='store-inventory'),
    path('inventory/low-stock/', views.low_stock_items_view, name='low-stock-items'),
    path('transactions/', views.InventoryTransactionListCreateView.as_view(), name='transaction-list-create'),
    
    # Admin stock management endpoints
    path('admin/add-stock/', views.admin_add_stock_view, name='admin-add-stock'),
    path('admin/update-stock/', views.admin_update_stock_view, name='admin-update-stock'),
    path('admin/store/<int:store_id>/stock/', views.admin_store_stock_view, name='admin-store-stock'),
    
    # Inventory transfer endpoints
    path('transfers/', views.InventoryTransferListCreateView.as_view(), name='transfer-list-create'),
    path('transfers/batch/', views.create_batch_transfer, name='batch-transfer'),
    path('transfers/<int:pk>/', views.InventoryTransferDetailView.as_view(), name='transfer-detail'),
    path('transfers/history/', views.inventory_transfer_history, name='transfer-history'),
]