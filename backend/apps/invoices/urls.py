from django.urls import path
from . import views

urlpatterns = [
    path('customers/', views.CustomerListCreateView.as_view(), name='customer-list-create'),
    path('customers/<int:pk>/', views.CustomerDetailView.as_view(), name='customer-detail'),
    path('', views.InvoiceListCreateView.as_view(), name='invoice-list-create'),
    path('<int:pk>/', views.InvoiceDetailView.as_view(), name='invoice-detail'),
    path('<int:invoice_id>/pdf/', views.generate_pdf_view, name='invoice-pdf'),
    path('stats/', views.invoice_stats_view, name='invoice-stats'),
]